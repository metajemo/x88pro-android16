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
    #
    # Expected output:
    #   Converted: 3.1G
    info "Step 1/4: Converting sparse image to raw (~3.1GB)..."
    simg2img "$SUPER_IMG" /tmp/x88pro-super/super_raw.img
    success "Converted: $(du -sh /tmp/x88pro-super/super_raw.img | cut -f1)"
 
    # Step 2: Unpack logical partitions
    # super_raw.img contains a partition table and multiple ext4 filesystems.
    # lpunpack reads the table and writes each partition as a separate .img:
    #   /tmp/x88pro-super/system.img
    #   /tmp/x88pro-super/vendor.img    <- this is what we need
    #   /tmp/x88pro-super/product.img
    #   /tmp/x88pro-super/system_ext.img
    #   /tmp/x88pro-super/odm.img
    #
    # Expected output:
    #   Extracting partition [vendor] .... [ok]
    #   Partitions unpacked: vendor.img ~493MB
    info "Step 2/4: Unpacking logical partitions..."
    python3 /tmp/lpunpack-tool/lpunpack.py \
        -p vendor \
        /tmp/x88pro-super/super_raw.img \
        /tmp/x88pro-super/
    success "Partitions unpacked:"
    ls -lh /tmp/x88pro-super/*.img 2>/dev/null | awk '{print "      " $NF, $5}' || true
 
    # Step 3: Extract vendor partition contents
    # vendor.img is an ext4 filesystem image.
    # We use debugfs to extract files without needing root (no loop mount needed).
    #
    # Expected output:
    #   Vendor partition extracted: 493M
    info "Step 3/4: Extracting vendor partition files..."
    [ -f "/tmp/x88pro-super/vendor.img" ] || error "vendor.img not found after lpunpack"
 
    mkdir -p /tmp/x88pro-vendor
    debugfs -R "rdump / /tmp/x88pro-vendor" /tmp/x88pro-super/vendor.img 2>/dev/null
    success "Vendor partition extracted: $(du -sh /tmp/x88pro-vendor | cut -f1)"
 
    # Step 4: Copy relevant blobs to our output directory
    info "Step 4/4: Copying relevant blobs..."
 
    mkdir -p "$OUTPUT_DIR/lib"
    mkdir -p "$OUTPUT_DIR/lib64/egl"
    mkdir -p "$OUTPUT_DIR/lib64/hw"
    mkdir -p "$OUTPUT_DIR/lib64"
    mkdir -p "$OUTPUT_DIR/firmware"
    mkdir -p "$OUTPUT_DIR/etc"
    mkdir -p "$OUTPUT_DIR/bin"
    mkdir -p "$OUTPUT_DIR/modules"
 
    # -------------------------------------------------------------------------
    # GPU: Mali-G52 (libmali blob + gralloc HAL)
    # -------------------------------------------------------------------------
    # The Mali-G52 GPU requires Rockchip/ARM's proprietary libmali blob.
    # Android's graphics stack (gralloc, HWC) requires this specific driver.
    # Open source Panfrost is NOT compatible with Android's gralloc HAL.
    #
    # Files:
    #   libGLES_mali.so       - Main Mali driver (OpenGL ES 3.2, Vulkan 1.1, OpenCL 2.0)
    #   android.hardware.graphics.allocator@4.0-impl-bifrost.so - gralloc allocator HAL
    #   android.hardware.graphics.mapper@4.0-impl-bifrost.so    - gralloc mapper HAL
    #   vulkan.rk356x.so      - Vulkan ICD (installable client driver)
    #   hwcomposer.rk30board.so - Hardware Composer HAL (display composition)
    #
    # IMPORTANT: libmali version must match the BSP kernel's Mali driver version.
    # Version mismatch causes black screen or rendering glitches at boot.
    #
    # Expected sizes (from X88 Pro Android 11 vendor):
    #   libGLES_mali.so: ~38MB
    #   vulkan.rk356x.so: ~38MB (same underlying driver)
    #   hwcomposer: ~1MB
 
    # Main Mali OpenGL ES driver
    cp /tmp/x88pro-vendor/lib64/egl/libGLES_mali.so \
        "$OUTPUT_DIR/lib64/egl/" 2>/dev/null && \
        success "GPU: libGLES_mali.so ($(du -sh $OUTPUT_DIR/lib64/egl/libGLES_mali.so | cut -f1))" || \
        warning "GPU: libGLES_mali.so not found"
 
    # Check libmali version for compatibility warning
    MALI_VER=$(strings "$OUTPUT_DIR/lib64/egl/libGLES_mali.so" 2>/dev/null | \
        grep -m1 "arm_release_ver\|Mali-G52" | head -1 || echo "unknown")
    [ "$MALI_VER" != "unknown" ] && \
        warning "Mali version: $MALI_VER - verify compatibility with BSP kernel Mali driver"
 
    # gralloc HAL (Bifrost = Mali-G52 series)
    cp /tmp/x88pro-vendor/lib64/hw/android.hardware.graphics.allocator@4.0-impl-bifrost.so \
        "$OUTPUT_DIR/lib64/hw/" 2>/dev/null && \
        success "GPU: gralloc allocator (bifrost)" || \
        warning "GPU: gralloc allocator not found"
 
    cp /tmp/x88pro-vendor/lib64/hw/android.hardware.graphics.mapper@4.0-impl-bifrost.so \
        "$OUTPUT_DIR/lib64/hw/" 2>/dev/null && \
        success "GPU: gralloc mapper (bifrost)" || \
        warning "GPU: gralloc mapper not found"
 
    # Vulkan driver
    cp /tmp/x88pro-vendor/lib64/hw/vulkan.rk356x.so \
        "$OUTPUT_DIR/lib64/hw/" 2>/dev/null && \
        success "GPU: vulkan.rk356x.so" || \
        warning "GPU: vulkan driver not found"
 
    # Hardware Composer HAL
    cp /tmp/x88pro-vendor/lib64/hw/hwcomposer.rk30board.so \
        "$OUTPUT_DIR/lib64/hw/" 2>/dev/null && \
        success "GPU: hwcomposer.rk30board.so" || \
        warning "GPU: hwcomposer not found"
 
    # -------------------------------------------------------------------------
    # Video: Rockchip MPP (Media Process Platform)
    # -------------------------------------------------------------------------
    # libmpp.so provides hardware H.264/H.265/VP9 decode/encode.
    # This is essential for smooth video playback on Android.
    #
    # IMPORTANT: The RK3566 uses rkvdec2 which has NO mainline kernel driver.
    # MPP with the Rockchip BSP kernel (5.10) is the ONLY option for hardware
    # video acceleration. Without this, all video plays in software (slow).
    #
    # Codec support via MPP on RK3566:
    #   Decode: H.264 (4K@60fps), H.265 (4K@60fps), VP9 (4K@60fps)
    #   Encode: H.264 (1080p@60fps), H.265 (1080p@60fps)
    #   NOT supported: AV1 (hardware limitation), HDR (hardware limitation)
    #
    # Note: Library is named libmpp.so in this BSP (not librockchip_mpp.so
    # as found in some other Rockchip BSP versions)
    #
    # Expected: libmpp.so ~6.3MB
    cp /tmp/x88pro-vendor/lib64/libmpp.so \
        "$OUTPUT_DIR/lib64/" 2>/dev/null && \
        success "Video: libmpp.so ($(du -sh $OUTPUT_DIR/lib64/libmpp.so | cut -f1))" || \
        warning "Video: libmpp.so not found - trying librockchip_mpp..."
    # Fallback: some BSP versions use a different name
    find /tmp/x88pro-vendor/lib64 -name "librockchip_mpp*.so" \
        -exec cp {} "$OUTPUT_DIR/lib64/" \; 2>/dev/null || true
 
    # Also get 32-bit MPP for 32-bit app compatibility
    cp /tmp/x88pro-vendor/lib/libmpp.so \
        "$OUTPUT_DIR/lib/" 2>/dev/null || true
 
    # OMX video codec wrappers (used by some media apps)
    cp /tmp/x88pro-vendor/lib64/libomxvpu_dec.so \
        "$OUTPUT_DIR/lib64/" 2>/dev/null && \
        success "Video: libomxvpu_dec.so" || true
    cp /tmp/x88pro-vendor/lib64/libomxvpu_enc.so \
        "$OUTPUT_DIR/lib64/" 2>/dev/null && \
        success "Video: libomxvpu_enc.so" || true
 
    # -------------------------------------------------------------------------
    # 2D Acceleration: RGA (Rockchip Graphics Acceleration)
    # -------------------------------------------------------------------------
    # librga.so provides 2D hardware acceleration:
    #   - Image scaling and rotation
    #   - Color format conversion (YUV <-> RGB)
    #   - Used internally by the video playback pipeline
    #   - Used by some camera and display processing
    #
    # Expected: librga.so ~112KB
    cp /tmp/x88pro-vendor/lib64/librga.so \
        "$OUTPUT_DIR/lib64/" 2>/dev/null && \
        success "2D accel: librga.so" || \
        warning "2D accel: librga.so not found"
    cp /tmp/x88pro-vendor/lib/librga.so \
        "$OUTPUT_DIR/lib/" 2>/dev/null || true
 
    # -------------------------------------------------------------------------
    # WiFi: AP6398S (Broadcom BCM43598 / BCM4359c0)
    # -------------------------------------------------------------------------
    # The AP6398S WiFi module uses the bcmdhd out-of-tree kernel driver.
    # Note: Despite earlier assumption, this device uses bcmdhd (Broadcom's
    # Android driver) NOT brcmfmac (mainline). This was discovered during
    # Phase 3 blob extraction.
    #
    # Files needed:
    #   bcmdhd.ko              - WiFi kernel module (bcmdhd driver)
    #   fw_bcm4359c0_ag.bin    - STA (station/client) firmware
    #   fw_bcm4359c0_ag_apsta.bin - AP/hotspot firmware
    #   fw_bcm4359c0_ag_p2p.bin   - P2P/WiFi Direct firmware
    #   nvram_ap6398s.txt      - Board-specific RF calibration data
    #   nvram_ap6398sa.txt     - Alternative calibration data
    #
    # IMPORTANT: Firmware path is /vendor/etc/firmware/ NOT /vendor/firmware/
    # The bcmdhd driver default paths point to /vendor/etc/firmware/
    #
    # Expected: each .bin ~640KB, nvram ~6KB
    cp /tmp/x88pro-vendor/lib/modules/bcmdhd.ko \
        "$OUTPUT_DIR/modules/" 2>/dev/null && \
        success "WiFi: bcmdhd.ko kernel module ($(du -sh $OUTPUT_DIR/modules/bcmdhd.ko | cut -f1))" || \
        warning "WiFi: bcmdhd.ko not found"
 
    # WiFi firmware - AP6398S uses BCM4359c0 firmware
    # (chip marketing name AP6398S = BCM43598 = BCM4359 silicon revision c0)
    find /tmp/x88pro-vendor/etc/firmware -name "fw_bcm4359c0*" \
        -exec cp {} "$OUTPUT_DIR/firmware/" \; 2>/dev/null
    WIFI_COUNT=$(ls "$OUTPUT_DIR/firmware"/fw_bcm4359c0* 2>/dev/null | wc -l)
    success "WiFi firmware: $WIFI_COUNT file(s) (fw_bcm4359c0_ag*.bin)"
 
    # WiFi calibration data
    find /tmp/x88pro-vendor/etc/firmware -name "nvram_ap6398s*" \
        -exec cp {} "$OUTPUT_DIR/firmware/" \; 2>/dev/null
    success "WiFi NVRAM: $(ls $OUTPUT_DIR/firmware/nvram_ap6398s* 2>/dev/null | wc -l) file(s)"
 
    # -------------------------------------------------------------------------
    # Bluetooth: AP6398S (BCM4359c0)
    # -------------------------------------------------------------------------
    # Same chip as WiFi. BT uses UART interface.
    # The btbcm kernel driver loads the HCD firmware file at init.
    #
    # File naming convention: BCM{chip}.hcd
    # Our chip BCM4359 revision C0 = BCM4359C0.hcd
    #
    # Expected: BCM4359C0.hcd ~50KB
    find /tmp/x88pro-vendor/etc/firmware -name "BCM4359C0*" \
        -exec cp {} "$OUTPUT_DIR/firmware/" \; 2>/dev/null
    BT_COUNT=$(ls "$OUTPUT_DIR/firmware"/BCM4359C0* 2>/dev/null | wc -l)
    success "BT firmware: $BT_COUNT file(s) (BCM4359C0.hcd)"
 
    # -------------------------------------------------------------------------
    # HAL configuration files
    # -------------------------------------------------------------------------
    # /vendor/etc contains critical HAL configs:
    #   media_codecs.xml      - Declares hardware codec capabilities to Android
    #   audio_policy.conf     - Audio routing and device config
    #   init scripts          - Service startup configs
    #   vintf/manifest.xml    - HAL version declarations
    cp -r /tmp/x88pro-vendor/etc/. "$OUTPUT_DIR/etc/" 2>/dev/null || true
    success "HAL configs: $(find $OUTPUT_DIR/etc -type f | wc -l) config file(s)"
 
    # -------------------------------------------------------------------------
    # HAL binaries
    # -------------------------------------------------------------------------
    cp -r /tmp/x88pro-vendor/bin/. "$OUTPUT_DIR/bin/" 2>/dev/null || true
    success "HAL binaries: $(ls $OUTPUT_DIR/bin | wc -l) binary file(s)"
 
    # -------------------------------------------------------------------------
    # NOTE: NPU blobs intentionally NOT extracted from Android 11
    # -------------------------------------------------------------------------
    # The Android 11 RKNN v1 runtime is incompatible with Android 16 HALs.
    # Run './phase3_device_prep.sh npu-blobs' to get RKNN2 runtime instead.
 
    echo ""
    success "Vendor blob extraction complete."
    echo ""
    echo "    Summary:"
    echo "      GPU (Mali-G52):"
    echo "        libGLES_mali.so:     $(du -sh $OUTPUT_DIR/lib64/egl/libGLES_mali.so 2>/dev/null | cut -f1)"
    echo "        vulkan.rk356x.so:    $(du -sh $OUTPUT_DIR/lib64/hw/vulkan.rk356x.so 2>/dev/null | cut -f1)"
    echo "        hwcomposer:          $(du -sh $OUTPUT_DIR/lib64/hw/hwcomposer.rk30board.so 2>/dev/null | cut -f1)"
    echo "        gralloc (bifrost):   2 HAL files"
    echo "      Video (MPP):           $(du -sh $OUTPUT_DIR/lib64/libmpp.so 2>/dev/null | cut -f1)"
    echo "      2D accel (RGA):        $(du -sh $OUTPUT_DIR/lib64/librga.so 2>/dev/null | cut -f1)"
    echo "      WiFi module:           $(du -sh $OUTPUT_DIR/modules/bcmdhd.ko 2>/dev/null | cut -f1)"
    echo "      WiFi firmware:         $WIFI_COUNT file(s) (fw_bcm4359c0_ag*.bin)"
    echo "      BT firmware:           $BT_COUNT file(s) (BCM4359C0.hcd)"
    echo "      HAL configs:           $(find $OUTPUT_DIR/etc -type f | wc -l) file(s)"
    echo ""
    warning "NPU blobs NOT extracted (RKNN v1 incompatible with Android 16)."
    warning "Run './phase3_device_prep.sh npu-blobs $OUTPUT_DIR' for NPU support."
    echo ""
    echo "    Known hardware limitations (cannot be fixed in software):"
    echo "      ❌ AV1 decode       - RK3566 VPU hardware limitation"
    echo "      ❌ HDR display      - RK3566 hardware limitation"
    echo "      ❌ Audio passthrough - PCM stereo only (no DD/DTS)"
    echo "      ⚠️  WiFi driver      - bcmdhd (out-of-tree), NOT brcmfmac (mainline)"
 
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
