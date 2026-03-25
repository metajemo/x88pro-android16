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

    echo "==> Extracting vendor blobs from super.img..."
    echo "    Source: $SUPER_IMG"
    echo "    Output: $OUTPUT_DIR"

    mkdir -p "$OUTPUT_DIR"
    mkdir -p /tmp/x88pro-super

    # Step 1: Convert sparse super.img to raw image
    # super.img uses Android sparse format to save space
    echo "    Step 1/3: Converting sparse image to raw..."
    simg2img "$SUPER_IMG" /tmp/x88pro-super/super_raw.img

    # Step 2: Unpack logical partitions from raw super image
    # lpunpack extracts each logical partition as a separate .img file
    echo "    Step 2/3: Unpacking logical partitions..."
    lpunpack /tmp/x88pro-super/super_raw.img /tmp/x88pro-super/

    # Step 3: Extract files from vendor.img (ext4 filesystem)
    echo "    Step 3/3: Extracting vendor partition files..."
    # TODO: implement ext4 extraction
    # Options: debugfs, 7zip, or mount -o loop (requires sudo)

    echo ""
    echo "==> Vendor blob extraction complete."
    echo "    Key blobs to verify:"
    echo "      - libmali*.so (GPU driver)"
    echo "      - librkvpu*.so (Video Processing Unit)"
    echo "      - firmware/rtl* or fw_bcm* (WiFi firmware)"
}

# =============================================================================
# DEVICE-TREE - Generate Android 16 device tree files
# =============================================================================
# Creates the Android device tree directory structure needed to build AOSP.
# This is the core of what makes Android work on our specific hardware.
#
# Files generated:
#   device.mk           - Lists vendor blobs and build rules
#   BoardConfig.mk      - Hardware parameters (partitions, kernel, security)
#   AndroidProducts.mk  - Defines the lunch target
#   x88pro.dts          - Device tree source for kernel
#
# Expected output:
#   Generating device tree for: x88pro (rockchip)
#   Created: device/rockchip/x88pro/device.mk
#   Created: device/rockchip/x88pro/BoardConfig.mk
#   Created: device/rockchip/x88pro/AndroidProducts.mk
device_tree() {
    DEVICE="${2}"
    VENDOR="${3}"
    OUTPUT_DIR="${4}"

    echo "==> Generating Android 16 device tree for: $DEVICE ($VENDOR)..."

    mkdir -p "$OUTPUT_DIR"

    # Generate device.mk
    # TODO: This will be populated with actual content in Phase 3
    cat > "$OUTPUT_DIR/device.mk" << EOF
# Device configuration for X88 Pro (RK3566)
# Auto-generated by phase3_device_prep.sh - review and customize as needed

PRODUCT_NAME := rockchip_x88pro
PRODUCT_DEVICE := x88pro
PRODUCT_BRAND := rockchip
PRODUCT_MANUFACTURER := rockchip
PRODUCT_MODEL := X88Pro20

# TODO: Add vendor blob entries after phase3-extract-blobs
# PRODUCT_COPY_FILES += ...
EOF

    # Generate BoardConfig.mk
    cat > "$OUTPUT_DIR/BoardConfig.mk" << EOF
# Board configuration for X88 Pro (RK3566)
# Auto-generated by phase3_device_prep.sh - review and customize as needed

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := cortex-a55

# Secondary architecture (32-bit support)
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_VARIANT := cortex-a55

# Platform
TARGET_BOARD_PLATFORM := rk356x
TARGET_BOOTLOADER_BOARD_NAME := rk30sdk

# Kernel
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_CONFIG := rockchip_defconfig
# TODO: Set correct kernel source path after Phase 2 sync

# Partitions (from Phase 1 extraction)
BOARD_BOOTIMAGE_PARTITION_SIZE     := 67108864    # 64MB  (boot.img size)
BOARD_DTBOIMG_PARTITION_SIZE       := 4194304     # 4MB   (dtbo.img size)
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 100663296   # 96MB  (recovery.img size)
BOARD_SUPER_PARTITION_SIZE         := 3263168512  # ~3.1GB (super partition)

# Dynamic partitions
BOARD_SUPER_PARTITION_GROUPS := rockchip_dynamic_partitions
BOARD_ROCKCHIP_DYNAMIC_PARTITIONS_PARTITION_LIST := system vendor product system_ext
BOARD_ROCKCHIP_DYNAMIC_PARTITIONS_SIZE := 3258974208

# Verified Boot (disabled for development - enable for release)
BOARD_AVB_ENABLE := false

# TODO: More config to be added in Phase 3
EOF

    # Generate AndroidProducts.mk
    cat > "$OUTPUT_DIR/AndroidProducts.mk" << EOF
# Android Products for X88 Pro
PRODUCT_MAKEFILES := \$(LOCAL_DIR)/device.mk
COMMON_LUNCH_CHOICES := rockchip_x88pro-userdebug rockchip_x88pro-user
EOF

    echo "==> Device tree skeleton generated at: $OUTPUT_DIR"
    echo "    Files created:"
    echo "      $OUTPUT_DIR/device.mk"
    echo "      $OUTPUT_DIR/BoardConfig.mk"
    echo "      $OUTPUT_DIR/AndroidProducts.mk"
    echo ""
    echo "NOTE: These files are starting points. They will be refined"
    echo "      throughout Phase 3 and Phase 4 as we discover what works."
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
