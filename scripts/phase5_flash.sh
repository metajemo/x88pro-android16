#!/bin/bash
# =============================================================================
# X88 Pro RK3566 - Phase 5: Flash Android 16 to Device
# =============================================================================
# Flashes the built Android 16 images to the X88 Pro box.
#
# The X88 Pro uses Rockchip's proprietary loader mode for flashing
# (NOT standard fastboot). This requires rkdeveloptool.
#
# Usage:
#   ./phase5_flash.sh flash AOSP_DIR DEVICE BOX_IP
#   ./phase5_flash.sh verify BOX_IP
#   ./phase5_flash.sh restore BACKUP_DIR   - Restore original Android 11
#
# WARNING: Flashing replaces Android 11. Keep Phase 1 backup safe!
# =============================================================================

set -e

COMMAND="${1}"

# =============================================================================
# CHECK - Verify rkdeveloptool is installed
# =============================================================================
# rkdeveloptool is Rockchip's open source flashing utility.
# It communicates with the RK3566 in MaskROM/loader mode.
#
# Install on Ubuntu:
#   sudo apt-get install libusb-1.0-0-dev
#   git clone https://github.com/rockchip-linux/rkdeveloptool
#   cd rkdeveloptool && autoreconf -i && ./configure && make
#   sudo make install
check_rkdeveloptool() {
    if ! command -v rkdeveloptool &>/dev/null; then
        echo "ERROR: rkdeveloptool not found."
        echo ""
        echo "Install it with:"
        echo "  sudo apt-get install libusb-1.0-0-dev"
        echo "  git clone https://github.com/rockchip-linux/rkdeveloptool"
        echo "  cd rkdeveloptool && autoreconf -i && ./configure && make"
        echo "  sudo make install"
        exit 1
    fi
    echo "  rkdeveloptool: $(rkdeveloptool --version 2>&1 | head -1)"
}

# Check simg2img is available (needed to unsparse super.img before flashing)
check_simg2img() {
    if ! command -v simg2img &>/dev/null; then
        echo "ERROR: simg2img not found."
        echo ""
        echo "Install it with:"
        echo "  sudo apt-get install android-sdk-libsparse-utils"
        exit 1
    fi
}

# Write a named partition using rkdeveloptool.
# Requires device in loader mode (adb reboot loader).
# Usage: flash_partition <partition_name> <image_file>
flash_partition() {
    local name="$1"
    local img="$2"
    echo "    Flashing ${name}... ($(du -h "$img" | cut -f1))"
    rkdeveloptool write-partition "$name" "$img"
}

# =============================================================================
# FLASH - Flash Android 16 images to device
# =============================================================================
# Puts the device into Rockchip loader mode and flashes all partitions.
#
# HOW TO ENTER LOADER MODE on X88 Pro:
#   Method 1 (software - preferred):
#     adb reboot loader
#   Method 2 (hardware - if Method 1 fails):
#     1. Unplug power
#     2. Hold the RESET/UPDATE pinhole button
#     3. Plug power back in while holding the button
#     4. Release after 3 seconds
#
# Expected output:
#   Downloading bootloader...
#   Downloading trust...
#   Downloading boot...
#   Downloading super...
#   Flashing complete. Device rebooting...
flash() {
    AOSP_DIR="${2}"
    DEVICE="${3}"
    BOX_IP="${4}"
    IMG_DIR="$AOSP_DIR/out/target/product/$DEVICE"

    echo "==> Preparing to flash Android 16..."
    echo ""
    echo "IMPORTANT: Make sure you have a backup from Phase 1 before continuing!"
    read -p "Do you have a Phase 1 backup? [y/N] " confirm
    [ "$confirm" = "y" ] || { echo "Aborting. Run Phase 1 first!"; exit 1; }

    # Verify built images exist
    for img in boot.img super.img; do
        [ -f "$IMG_DIR/$img" ] || {
            echo "ERROR: $IMG_DIR/$img not found. Run Phase 4 first."
            exit 1
        }
    done

    check_rkdeveloptool
    check_simg2img

    echo ""
    echo "==> Rebooting device into loader mode..."
    adb connect "$BOX_IP:5555" 2>/dev/null || true
    adb root 2>/dev/null || true
    adb reboot loader 2>/dev/null || true
    # If device is already in loader mode (USB), adb will fail — that's fine.

    # RK3566 takes ~4s to enumerate in loader mode after reboot
    echo "    Waiting for device to enter loader mode..."
    sleep 6

    # Expected: "DevNo=1  Vid=0x2207,Pid=0x350b,LocationID=XXX  Loader"
    # Pid 0x350b = RK3566 in loader mode
    # Pid 0x330c = RK3566 in MaskROM mode (use hardware button method)
    echo "==> Checking for device in loader mode..."
    if ! rkdeveloptool ld 2>&1 | grep -q "Loader"; then
        echo ""
        echo "ERROR: Device not detected in loader mode."
        echo ""
        echo "Manual loader mode entry (hardware method):"
        echo "  1. Unplug power from X88 Pro"
        echo "  2. Insert a pin into the RESET/UPDATE pinhole (near AV port)"
        echo "  3. Hold the pin while plugging power back in"
        echo "  4. Hold for 3 seconds then release"
        echo "  5. Re-run this script"
        exit 1
    fi
    rkdeveloptool ld

    echo ""
    echo "==> Flashing Android 16 partitions..."
    echo "    NOTE: Keeping stock uboot/trust bootloader (safer, avoids brick risk)"
    echo ""

    # Boot partition: kernel + ramdisk (~64MB)
    flash_partition boot "$IMG_DIR/boot.img"

    # Device tree overlays (~157KB)
    # Built from BSP kernel: rk3566-box-demo-v10.dtb via mkdtimg
    # Prebuilt in device/rockchip/x88pro/prebuilt/dtbo.img
    flash_partition dtbo "$IMG_DIR/dtbo.img"

    # AVB (Android Verified Boot) metadata (~1MB)
    # Must match boot/dtbo/super content; flashed after them
    flash_partition vbmeta "$IMG_DIR/vbmeta.img"

    # Super partition: system + vendor + product (~3.1GB)
    # AOSP builds super.img as a sparse image; rkdeveloptool needs raw.
    echo "    Preparing super.img for flashing..."
    SUPER_RAW="/tmp/x88pro_super_raw_$$.img"
    if file "$IMG_DIR/super.img" | grep -q "Android sparse"; then
        echo "    Converting sparse super.img → raw (~3.1GB, takes ~30s)..."
        simg2img "$IMG_DIR/super.img" "$SUPER_RAW"
    else
        # Already raw
        SUPER_RAW="$IMG_DIR/super.img"
    fi
    echo "    Flashing super (~3.1GB — expect 5-15 min over USB 2.0)..."
    rkdeveloptool write-partition super "$SUPER_RAW"
    # Clean up temp file if we created one
    [ "$SUPER_RAW" != "$IMG_DIR/super.img" ] && rm -f "$SUPER_RAW"

    echo ""
    echo "==> Rebooting device..."
    rkdeveloptool rd

    echo ""
    echo "==> Flash complete! Device is rebooting into Android 16."
    echo "    First boot takes 3-5 minutes (dex optimization) — this is normal."
    echo "    Monitor with: adb connect $BOX_IP:5555 && adb logcat"
    echo "    Verify with:  $0 verify $BOX_IP"
}

# =============================================================================
# VERIFY - Verify Android 16 is running correctly
# =============================================================================
# Reconnects via ADB and checks the Android version.
#
# Expected output:
#   Android version: 16
#   Build: rockchip/x88pro/x88pro:16/...
#   SUCCESS: Android 16 is running on X88 Pro!
verify() {
    BOX_IP="${2}"

    echo "==> Verifying Android 16 installation..."
    echo "    Connecting to $BOX_IP..."

    sleep 10  # Give device time to boot

    adb connect "$BOX_IP:5555"

    VERSION=$(adb shell getprop ro.build.version.release)
    BUILD=$(adb shell getprop ro.build.fingerprint)

    echo ""
    echo "  Android version: $VERSION"
    echo "  Build: $BUILD"
    echo ""

    if [ "$VERSION" = "16" ]; then
        echo "SUCCESS: Android 16 is running on your X88 Pro!"
    else
        echo "WARNING: Expected Android 16, got Android $VERSION"
        echo "         The device may still be booting, or flashing may have failed."
        echo "         Try again in a few minutes."
    fi
}

# =============================================================================
# RESTORE - Restore original Android 11
# =============================================================================
# Uses the Phase 1 backup to restore the original firmware.
# This is your safety net if anything goes wrong.
restore() {
    BACKUP_DIR="${2}"

    echo "==> Restoring original Android 11 from backup..."
    echo "    Backup dir: $BACKUP_DIR"

    # Verify backup exists
    for img in boot.img uboot.img trust.img super.img vbmeta.img; do
        [ -f "$BACKUP_DIR/$img" ] || {
            echo "ERROR: $BACKUP_DIR/$img not found. Backup may be incomplete!"
            exit 1
        }
    done

    check_rkdeveloptool
    check_simg2img

    echo "    All backup files verified."
    echo ""
    read -p "This will restore Android 11 and ERASE Android 16. Continue? [y/N] " confirm
    [ "$confirm" = "y" ] || exit 0

    echo ""
    echo "==> Entering loader mode for restore..."
    echo "    Hardware method required (software reboot may not work if A16 is broken):"
    echo "    1. Unplug power"
    echo "    2. Hold RESET/UPDATE pinhole button"
    echo "    3. Plug power while holding — release after 3s"
    echo ""
    read -p "Device ready in loader mode? [y/N] " ready
    [ "$ready" = "y" ] || exit 0

    echo "==> Checking for device in loader mode..."
    if ! rkdeveloptool ld 2>&1 | grep -q "Loader"; then
        echo "ERROR: Device not found in loader mode. Try hardware method above."
        exit 1
    fi

    echo ""
    echo "==> Restoring Android 11 partitions from backup..."
    echo ""

    # Restore bootloader chain (safe — these are original Rockchip images)
    flash_partition uboot   "$BACKUP_DIR/uboot.img"
    flash_partition trust   "$BACKUP_DIR/trust.img"
    flash_partition dtbo    "$BACKUP_DIR/dtbo.img"
    flash_partition vbmeta  "$BACKUP_DIR/vbmeta.img"
    flash_partition boot    "$BACKUP_DIR/boot.img"

    # super.img from Phase 1 is a raw dump — no sparse conversion needed
    echo "    Flashing super (~3.1GB — expect 5-15 min over USB 2.0)..."
    rkdeveloptool write-partition super "$BACKUP_DIR/super.img"

    echo ""
    echo "==> Rebooting device..."
    rkdeveloptool rd

    echo ""
    echo "==> Restore complete! Device is rebooting into Android 11."
    echo "    First boot after restore takes ~2 minutes."
}

# --- Main --------------------------------------------------------------------
case "$COMMAND" in
    flash)   flash "$@" ;;
    verify)  verify "$@" ;;
    restore) restore "$@" ;;
    *)
        echo "Usage: $0 {flash|verify|restore}"
        exit 1
        ;;
esac
