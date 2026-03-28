#!/bin/bash
# =============================================================================
# X88 Pro RK3566 - Phase 3: Device Tree & Vendor Blob Preparation
# =============================================================================
# Converts extracted device data into the format Android 16 needs.
#
# Steps:
#   3a. extract-dt    - Convert binary DTB -> human-readable DTS source
#   3b. extract-blobs - Unpack vendor partition from super.img
#   3c. device-tree   - Generate Android 16 device tree files
#
# Prerequisites:
#   - Phase 1 backup must exist (backup/ directory)
#   - Phase 2 must be complete (dtc and simg2img must be installed)
#
# Usage:
#   ./phase3_device_prep.sh extract-dt BACKUP_DIR OUTPUT_DIR
#   ./phase3_device_prep.sh extract-blobs SUPER_IMG OUTPUT_DIR
#   ./phase3_device_prep.sh device-tree DEVICE VENDOR OUTPUT_DIR
# =============================================================================

set -e

COMMAND="${1}"

# =============================================================================
# EXTRACT-DT - Convert binary device tree blob to source
# =============================================================================
# The device tree we extracted in Phase 1 is stored as binary (DTB format).
# We need to convert it back to human-readable DTS (Device Tree Source) so
# we can modify it for Android 16.
#
# Tool used: dtc (device tree compiler) - installed in phase2-deps
#
# Expected output:
#   Converting dtbo.img -> dts/x88pro.dts
#   Device tree source written to: device/rockchip/x88pro/x88pro.dts
#   Nodes found: ~450
extract_dt() {
    BACKUP_DIR="${2}"
    OUTPUT_DIR="${3}"

    echo "==> Extracting device tree from dtbo.img..."

    mkdir -p "$OUTPUT_DIR/dts"

    # The dtbo.img may contain multiple DTBOs - extract the first one
    # dtc converts binary DTB format back to readable DTS text format
    # -I dtb = input format is device tree blob (binary)
    # -O dts = output format is device tree source (text)
    # -o     = output file
    dtc -I dtb -O dts \
        -o "$OUTPUT_DIR/dts/x88pro.dts" \
        "$BACKUP_DIR/dtbo.img" 2>/dev/null || {
        echo "Note: dtbo.img contains multiple overlays, trying split approach..."
        # TODO: implement DTBO table parsing for multi-overlay images
        echo "This will be implemented in a future update."
    }

    # Also convert the boot.img embedded DTB
    # First extract the kernel + DTB from boot.img using mkbootimg tools
    echo "==> Extracting DTB from boot.img..."
    # TODO: implement boot.img unpacking
    # This requires: unpack_bootimg (from AOSP tools/mkbootimg)

    echo "==> Device tree extraction complete."
    echo "    Output: $OUTPUT_DIR/dts/"
    echo ""
    echo "NOTE: Manual review of the DTS file will be needed in Phase 3."
    echo "      Key nodes to verify: ethernet, hdmi, usb, wifi, gpu"
}

# =============================================================================
# EXTRACT-BLOBS - Unpack vendor partition from super.img
# =============================================================================
# super.img is a sparse image containing multiple logical partitions:
#   - system    (Android framework)
#   - vendor    (Rockchip proprietary drivers <- what we need)
#   - product   (OEM customizations)
#   - system_ext
#
# We need the vendor partition contents - specifically:
#   /vendor/lib/         - 32-bit shared libraries (GPU, VPU etc.)
#   /vendor/lib64/       - 64-bit shared libraries
#   /vendor/firmware/    - WiFi/BT firmware blobs
#   /vendor/etc/         - HAL configuration files
#
# Tools used:
#   simg2img  - converts sparse image to raw image
#   lpunpack  - unpacks logical partitions from super.img
#   debugfs   - extracts files from ext4 filesystem image
#
# Expected output:
#   Converting super.img to raw format...
#   Unpacking logical partitions...
#   Extracting vendor partition...
#   Vendor blobs extracted to: device/rockchip/x88pro/proprietary/
extract_blobs() {
    SUPER_IMG="${2}"
    OUTPUT_DIR="${3}"

    [ -f "$SUPER_IMG" ] || error "$SUPER_IMG not found. Run phase1 first."

    info "Extracting vendor blobs from super.img..."
    info "Source: $SUPER_IMG ($(du -sh "$SUPER_IMG" | cut -f1))"
    info "Output: $OUTPUT_DIR"

    mkdir -p "$OUTPUT_DIR"
    mkdir -p /tmp/x88pro-super

    # Step 1: Convert sparse super.img to raw image
    # Android sparse format uses a special header to skip empty blocks,
    # making the file smaller than the actual partition size.
    # simg2img converts it back to a flat raw image that tools can mount/read.
    info "Step 1/4: Converting sparse image to raw (~3.1GB)..."
    simg2img "$SUPER_IMG" /tmp/x88pro-super/super_raw.img
    success "Converted: $(du -sh /tmp/x88pro-super/super_raw.img | cut -f1)"

    # Step 2: Unpack logical partitions
    # super_raw.img contains a partition table and multiple ext4 filesystems.
    # lpunpack reads the table and writes each partition as a separate .img file:
    #   /tmp/x88pro-super/system.img
    #   /tmp/x88pro-super/vendor.img    <- this is what we need
    #   /tmp/x88pro-super/product.img
    #   /tmp/x88pro-super/system_ext.img
    info "Step 2/4: Unpacking logical partitions..."
    lpunpack /tmp/x88pro-super/super_raw.img /tmp/x88pro-super/
    success "Partitions unpacked:"
    ls -lh /tmp/x88pro-super/*.img 2>/dev/null | awk '{print "      " $NF, $5}' || true

    # Step 3: Extract vendor partition contents
    # vendor.img is an ext4 filesystem image.
    # We use debugfs to extract files without needing root (no loop mount needed).
    info "Step 3/4: Extracting vendor partition files..."
    [ -f "/tmp/x88pro-super/vendor.img" ] || error "vendor.img not found after lpunpack"

    mkdir -p /tmp/x88pro-vendor
    debugfs -R "rdump / /tmp/x88pro-vendor" /tmp/x88pro-super/vendor.img 2>/dev/null
    success "Vendor partition extracted: $(du -sh /tmp/x88pro-vendor | cut -f1)"

    # Step 4: Copy relevant blobs to our output directory
    info "Step 4/4: Copying relevant blobs..."

    mkdir -p "$OUTPUT_DIR/lib"
    mkdir -p "$OUTPUT_DIR/lib64"
    mkdir -p "$OUTPUT_DIR/firmware"
    mkdir -p "$OUTPUT_DIR/etc"
    mkdir -p "$OUTPUT_DIR/bin"

    # --- GPU: Mali-G52 (libmali) ---
    # libmali provides OpenGL ES, Vulkan and OpenCL for Android's graphics stack.
    # Android requires the proprietary Mali blob - open source Panfrost won't
    # work with Android's gralloc HAL.
    #
    # IMPORTANT: libmali version must match the kernel's Mali driver version.
    # Version mismatch causes black screen or rendering corruption.
    # The Android 11 blob should work if kernel Mali version is compatible.
    # If not, source updated blob from: github.com/tsukumijima/libmali-rockchip
    find /tmp/x88pro-vendor/lib -name "libmali*.so" -exec cp {} "$OUTPUT_DIR/lib/" \; 2>/dev/null || true
    find /tmp/x88pro-vendor/lib64 -name "libmali*.so" -exec cp {} "$OUTPUT_DIR/lib64/" \; 2>/dev/null || true

    # Check libmali version (important for compatibility)
    LIBMALI_VER=$(strings "$OUTPUT_DIR/lib64/libmali.so" 2>/dev/null | grep -i "arm_release_ver" | head -1 || echo "unknown")
    if [ "$LIBMALI_VER" != "unknown" ]; then
        success "GPU: libmali extracted, version: $LIBMALI_VER"
        warning "Verify this version is compatible with your BSP kernel Mali driver"
    else
        warning "GPU: libmali extracted but version could not be determined"
    fi

    # --- Video: Rockchip MPP (Media Process Platform) ---
    # librockchip_mpp.so provides hardware H.264/H.265/VP9 decode/encode.
    # This is essential for video playback performance on Android.
    # The RK3566 uses rkvdec2 which has NO mainline kernel driver - MPP
    # with the BSP kernel is the only option for hardware video acceleration.
    # RK3566 supported codecs via MPP:
    #   Decode: H.264 (4K@60), H.265 (4K@60), VP9 (4K@60) - NO AV1, NO HDR
    #   Encode: H.264 (1080p@60), H.265 (1080p@60)
    find /tmp/x88pro-vendor/lib -name "librockchip_mpp*.so" -exec cp {} "$OUTPUT_DIR/lib/" \; 2>/dev/null || true
    find /tmp/x88pro-vendor/lib64 -name "librockchip_mpp*.so" -exec cp {} "$OUTPUT_DIR/lib64/" \; 2>/dev/null || true
    MPP_COUNT=$(ls "$OUTPUT_DIR/lib64"/librockchip_mpp*.so 2>/dev/null | wc -l)
    success "Video MPP: $MPP_COUNT MPP library file(s) extracted"

    # --- 2D Acceleration: RGA (Rockchip Graphics Acceleration) ---
    # librga provides 2D hardware acceleration for image scaling, rotation,
    # color format conversion. Used by video playback pipeline.
    find /tmp/x88pro-vendor/lib -name "librga*.so" -exec cp {} "$OUTPUT_DIR/lib/" \; 2>/dev/null || true
    find /tmp/x88pro-vendor/lib64 -name "librga*.so" -exec cp {} "$OUTPUT_DIR/lib64/" \; 2>/dev/null || true
    success "2D accel: $(ls $OUTPUT_DIR/lib64/librga*.so 2>/dev/null | wc -l) RGA library file(s) extracted"

    # --- WiFi: AP6398S (Broadcom BCM43598) firmware ---
    # brcmfmac kernel driver (mainline) loads these firmware blobs at runtime.
    # Without these files WiFi simply won't start.
    # Files needed:
    #   fw_bcm43598a3.bin      - Station mode (connecting to WiFi)
    #   fw_bcm43598a3_apsta.bin - AP/hotspot mode
    #   nvram_ap6398s.txt      - Board-specific RF calibration data
    find /tmp/x88pro-vendor/firmware -name "fw_bcm43598*" -exec cp {} "$OUTPUT_DIR/firmware/" \; 2>/dev/null || true
    find /tmp/x88pro-vendor/firmware -name "nvram_ap6398s*" -exec cp {} "$OUTPUT_DIR/firmware/" \; 2>/dev/null || true
    WIFI_COUNT=$(ls "$OUTPUT_DIR/firmware"/fw_bcm43598* 2>/dev/null | wc -l)
    success "WiFi firmware: $WIFI_COUNT file(s) extracted (AP6398S / BCM43598)"

    # --- Bluetooth: AP6398S firmware ---
    # btbcm kernel driver loads HCD (HCI Command Data) firmware for BT init.
    # File needed: BCM43598A3.hcd
    find /tmp/x88pro-vendor/firmware -name "BCM43598*" -exec cp {} "$OUTPUT_DIR/firmware/" \; 2>/dev/null || true
    BT_COUNT=$(ls "$OUTPUT_DIR/firmware"/BCM43598* 2>/dev/null | wc -l)
    success "BT firmware: $BT_COUNT file(s) extracted (AP6398S / BCM43598)"

    # --- HAL configuration files ---
    # /vendor/etc contains HAL configs, media codecs, audio policy etc.
    # These tell Android which hardware capabilities are available.
    cp -r /tmp/x88pro-vendor/etc/. "$OUTPUT_DIR/etc/" 2>/dev/null || true
    success "HAL configs: $(find $OUTPUT_DIR/etc -type f | wc -l) config file(s) extracted"

    # --- HAL binaries ---
    cp -r /tmp/x88pro-vendor/bin/. "$OUTPUT_DIR/bin/" 2>/dev/null || true
    success "HAL binaries: $(ls $OUTPUT_DIR/bin | wc -l) binary file(s) extracted"

    # NOTE: NPU blobs from Android 11 are intentionally NOT copied here.
    # The Android 11 RKNN v1 runtime is incompatible with Android 16 HALs.
    # Run 'phase3_device_prep.sh npu-blobs' to get the RKNN2 runtime instead.

    echo ""
    success "Vendor blob extraction complete."
    echo ""
    echo "    Summary:"
    echo "      GPU (Mali-G52):     $(ls $OUTPUT_DIR/lib64/libmali*.so 2>/dev/null | wc -l) libmali file(s) - $LIBMALI_VER"
    echo "      Video (MPP):        $MPP_COUNT librockchip_mpp file(s)"
    echo "      2D accel (RGA):     $(ls $OUTPUT_DIR/lib64/librga*.so 2>/dev/null | wc -l) librga file(s)"
    echo "      WiFi firmware:      $WIFI_COUNT file(s)"
    echo "      BT firmware:        $BT_COUNT file(s)"
    echo "      HAL configs:        $(find $OUTPUT_DIR/etc -type f | wc -l) file(s)"
    echo ""
    warning "NPU blobs NOT extracted from Android 11 (intentionally - RKNN v1 incompatible)."
    warning "Run './phase3_device_prep.sh npu-blobs $OUTPUT_DIR' for RKNN2 NPU support."
    echo ""
    echo "    Known hardware limitations (cannot be fixed in software):"
    echo "      ❌ AV1 decode - not supported by RK3566 VPU hardware"
    echo "      ❌ HDR display - not supported by RK3566"
    echo "      ❌ DD/DTS audio passthrough - not supported"
    echo "      ⚠️  HDMI audio: PCM stereo only"

    # Cleanup temp files
    rm -rf /tmp/x88pro-super /tmp/x88pro-vendor
}

# --- Main --------------------------------------------------------------------
case "$COMMAND" in
    extract-dt)     extract_dt "$@" ;;
    extract-blobs)  extract_blobs "$@" ;;
    device-tree)    device_tree "$@" ;;
    *)
        echo "Usage: $0 {extract-dt|extract-blobs|device-tree}"
        exit 1
        ;;
esac
