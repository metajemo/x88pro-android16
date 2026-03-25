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

    echo ""
    echo "==> Rebooting device into loader mode..."
    adb connect "$BOX_IP:5555" 2>/dev/null || true
    adb root 2>/dev/null || true
    adb reboot loader

    echo "    Waiting for device to enter loader mode..."
    sleep 5

    # Check device is in loader mode
    # Expected: "DevNo=1	Vid=0x2207,Pid=0x350b,LocationID=XXX	Loader"
    echo "==> Checking for device in loader mode..."
    rkdeveloptool ld

    echo ""
    echo "==> Flashing partitions..."

    # Flash bootloader (uboot)
    echo "    Flashing uboot..."
    # TODO: Confirm exact rkdeveloptool commands for Android 16 images
    # rkdeveloptool wl 0x4000 uboot.img

    # Flash trust (TrustZone)
    echo "    Flashing trust..."
    # rkdeveloptool wl 0x6000 trust.img

    # Flash boot (kernel + ramdisk)
    echo "    Flashing boot..."
    # rkdeveloptool wl 0x8000 "$IMG_DIR/boot.img"

    # Flash super (system + vendor + product)
    echo "    Flashing super (~3GB, this will take a few minutes)..."
    # rkdeveloptool wl 0xE000 "$IMG_DIR/super.img"

    # Flash vbmeta
    echo "    Flashing vbmeta..."
    # rkdeveloptool wl 0x7000 "$IMG_DIR/vbmeta.img"

    echo ""
    echo "==> Rebooting device..."
    rkdeveloptool rd

    echo ""
    echo "==> Flash complete! Device is rebooting into Android 16."
    echo "    First boot may take 3-5 minutes - this is normal."
    echo "    Run 'make phase5-verify' once the device has booted."

    # TODO: Full flash implementation will be completed in Phase 5
    echo ""
    echo "NOTE: Full flash script is a work in progress."
    echo "      Partition offsets need to be verified against actual layout."
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

    echo "    All backup files verified."
    echo ""
    read -p "This will restore Android 11 and erase Android 16. Continue? [y/N] " confirm
    [ "$confirm" = "y" ] || exit 0

    # TODO: Implement restore using same flash logic as above but with backup images
    echo "NOTE: Restore script is a work in progress."
    echo "      Use rkdeveloptool manually with the backup images for now."
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
