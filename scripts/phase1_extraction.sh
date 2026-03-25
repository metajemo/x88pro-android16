#!/bin/bash
# =============================================================================
# X88 Pro RK3566 - Phase 1: Device Extraction Script
# =============================================================================
# This script extracts all necessary data from the X88 Pro Android box
# to prepare for building Android 16.
#
# Prerequisites:
#   - ADB installed on your system (Windows WSL or Linux)
#   - X88 Pro box connected to the same network
#   - Developer Options enabled on the box (Settings > About > tap Build Number 7 times)
#   - ADB over network enabled in Developer Options
#
# Usage:
#   chmod +x x88pro_phase1_extraction.sh
#   ./x88pro_phase1_extraction.sh <ip-address-of-box>
#
# Example:
#   ./x88pro_phase1_extraction.sh 192.168.1.105
# =============================================================================

# --- Configuration -----------------------------------------------------------

BOX_IP="${1}"                # IP address passed as first argument to the script
ADB_PORT="5555"              # Default ADB over network port
BACKUP_DIR="x88pro-backup"  # Local folder where all files will be saved

# --- Sanity check ------------------------------------------------------------

if [ -z "$BOX_IP" ]; then
    echo "ERROR: Please provide the box IP address as an argument."
    echo "Usage: $0 <ip-address>"
    exit 1
fi

# --- Setup -------------------------------------------------------------------

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"
echo "Backup directory: $BACKUP_DIR"
echo ""

# =============================================================================
# STEP 1: Connect to the box over the network via ADB
# =============================================================================
# Expected output:
#   connected to 192.168.1.105:5555
#
# If you see "failed to connect" check that:
#   - The box and your PC are on the same network
#   - ADB over network is enabled in Developer Options
#   - No firewall is blocking port 5555
echo "==> Connecting to box at $BOX_IP:$ADB_PORT ..."
adb connect "$BOX_IP:$ADB_PORT"
echo ""

# =============================================================================
# STEP 2: Restart ADB daemon as root
# =============================================================================
# The X88 Pro runs a 'userdebug' build which allows ADB to run as root.
# This is essential - without root we cannot read raw block devices (partitions).
#
# Expected output:
#   restarting adbd as root
#
# If you see "adbd cannot run as root in production builds" the box is running
# a production (user) build and this approach will not work - rooting via
# Magisk will be required instead.
echo "==> Restarting ADB as root ..."
adb root

# Give adbd a moment to restart
sleep 3

# Reconnect after root restart (adbd restarts itself, briefly disconnecting)
echo "==> Reconnecting after root restart ..."
adb connect "$BOX_IP:$ADB_PORT"
echo ""

# =============================================================================
# STEP 3: Verify connection and print device info
# =============================================================================
# Expected output:
#   List of devices attached
#   192.168.1.105:5555    device
#
# If the status shows "unauthorized" go to the box screen and accept
# the ADB authorization prompt.
# If the status shows "offline" wait a few seconds and try adb connect again.
echo "==> Verifying connection ..."
adb devices
echo ""

# =============================================================================
# STEP 4: Collect system information
# =============================================================================
echo "==> Collecting system information ..."

# Android version
# Expected output:
#   11
echo "Android version:"
adb shell getprop ro.build.version.release

# Android SDK level
# Expected output:
#   30
# (SDK 30 = Android 11, SDK 33 = Android 13, SDK 35 = Android 15, SDK 36 = Android 16)
echo "SDK level:"
adb shell getprop ro.build.version.sdk

# Device model name
# Expected output:
#   X88Pro20
echo "Model:"
adb shell getprop ro.product.model

# Manufacturer
# Expected output:
#   rockchip
echo "Manufacturer:"
adb shell getprop ro.product.manufacturer

# CPU information - shows number of cores, architecture and CPU part number
# Expected output (4 blocks like this, one per core):
#   processor       : 0
#   BogoMIPS        : 48.00
#   Features        : fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm lrcpc dcpop asimddp
#   CPU implementer : 0x41          <- 0x41 = ARM
#   CPU architecture: 8             <- ARMv8 = 64-bit
#   CPU variant     : 0x2
#   CPU part        : 0xd05         <- 0xd05 = Cortex-A55
#   CPU revision    : 0
#   ...repeated for processors 1, 2, 3...
#   Hardware        : Rockchip RK3566 BOX DEMO V10 ANDROID Board
#   Serial          : <unique device serial number>
echo "CPU info:"
adb shell cat /proc/cpuinfo

# Memory - first 5 lines show total and available RAM
# Expected output:
#   MemTotal:        7860196 kB     <- ~8GB RAM
#   MemFree:         3720116 kB     <- varies depending on what is running
#   MemAvailable:    6331840 kB
#   Buffers:            4096 kB
#   Cached:          2680576 kB
echo "Memory info:"
adb shell cat /proc/meminfo | head -5

# Storage usage per partition
# Expected output:
#   Filesystem             Size  Used Avail Use% Mounted on
#   tmpfs                  3.7G  824K  3.7G   1% /dev
#   /dev/block/dm-0        1.0G  1.0G     0 100% /              <- system (read-only)
#   /dev/block/dm-2        492M  491M     0 100% /vendor        <- vendor (read-only)
#   /dev/block/dm-3        758M  756M     0 100% /product       <- product (read-only)
#   /dev/block/mmcblk2p15  111G  2.7G  108G   3% /data         <- user data (~128GB)
#   ...
# Note: dm-* are dynamic partitions (system, vendor etc.) from the super partition
echo "Storage:"
adb shell df -h

# Kernel version and build date
# Expected output:
#   Linux localhost 4.19.172 #160 SMP PREEMPT Wed Jul 13 15:40:46 CST 2022 aarch64
#                  ^kernel   ^build              ^build date               ^architecture
# Note: kernel 4.19 is the version Rockchip ships with RK3566 Android 11
# Our Android 16 build will use a newer kernel (5.10 or later)
echo "Kernel:"
adb shell uname -a

# Board/platform identifiers - confirms RK3566/rk356x
# Expected output:
#   [ro.board.platform]: [rk356x]      <- platform family (rk356x covers RK3566/RK3568)
#   [ro.boot.hardware]: [rk30board]
#   [ro.hardware]: [rk30board]
#   [ro.product.board]: [rk30sdk]
echo "Board props:"
adb shell getprop | grep -i board

echo ""

# =============================================================================
# STEP 5: Save ALL system properties to a file
# =============================================================================
# getprop dumps every Android system property - useful reference for
# hardware configuration, build fingerprints, feature flags etc.
#
# Expected output: (no terminal output, just creates the file silently)
# The resulting getprop_backup.txt file will contain ~200+ lines like:
#   [ro.product.manufacturer]: [rockchip]
#   [ro.build.version.release]: [11]
#   [ro.board.platform]: [rk356x]
#   [ro.bootimage.build.fingerprint]: [rockchip/rk356x_box/rk356x_box:11/RQ2A.210505.003/builder_id:userdebug/release-keys]
#   [ro.product.brand]: [rockchip]
#   ...
echo "==> Saving all system properties to getprop_backup.txt ..."
adb shell getprop > "$BACKUP_DIR/getprop_backup.txt"
echo "Done."
echo ""

# =============================================================================
# STEP 6: List device tree nodes
# =============================================================================
# /proc/device-tree is a virtual filesystem exposing the hardware device tree.
# It describes every piece of hardware: SoC, memory, USB, HDMI, WiFi etc.
# This is essential for building a working kernel for the device.
#
# Expected output (partial - there will be ~150+ top-level entries):
#   aliases
#   chosen
#   cpus
#   ethernet@fe010000        <- Gigabit Ethernet controller
#   gpu@fde60000             <- Mali GPU
#   hdmi@fe0a0000            <- HDMI output
#   memory
#   npu@fde40000             <- Neural Processing Unit
#   pinctrl                  <- GPIO/pin configuration
#   rkvdec@fdf80200          <- hardware video decoder
#   serial@fe650000          <- UART serial ports
#   usb@fd800000             <- USB controllers
#   wireless-bluetooth        <- Bluetooth
#   wireless-wlan            <- WiFi
#   ...
echo "==> Listing device tree nodes ..."
adb shell ls /proc/device-tree
echo ""

# =============================================================================
# STEP 7: Pull the entire device tree
# =============================================================================
# Downloads all device tree files to our backup folder.
# These will be used to create the device tree source (DTS) for Android 16.
#
# Expected output:
#   /proc/device-tree/: 3977 files pulled, 0 skipped. 0.0 MB/s (49670 bytes in 66.543s)
#
# Note: Speed shows as 0.0 MB/s because files are tiny (mostly a few bytes each)
# but there are ~4000 of them so it still takes about a minute to transfer.
echo "==> Pulling device tree (this may take a minute) ..."
adb pull /proc/device-tree "$BACKUP_DIR/device-tree-backup"
echo ""

# =============================================================================
# STEP 8: Show available partition names
# =============================================================================
# /dev/block/by-name/ contains named symlinks to raw block devices.
# These are the partitions we need to back up.
#
# Expected output:
#   backup           <- factory backup partition
#   baseparameter    <- Rockchip display/hardware parameters
#   boot             <- kernel + ramdisk
#   cache            <- system cache
#   dtbo             <- device tree blob overlays
#   logo             <- boot logo image
#   metadata         <- dynamic partition metadata
#   misc             <- bootloader communication flags
#   mmcblk2          <- raw eMMC device
#   mmcblk2boot0     <- eMMC boot area 0 (contains bootrom code)
#   mmcblk2boot1     <- eMMC boot area 1
#   recovery         <- recovery OS
#   security         <- security keys partition
#   super            <- dynamic partition (system+vendor+product)
#   trust            <- ARM TrustZone firmware
#   uboot            <- U-Boot bootloader
#   userdata         <- user data (/data)
#   vbmeta           <- Android Verified Boot metadata
echo "==> Available partitions:"
adb shell ls /dev/block/by-name/
echo ""

# =============================================================================
# STEP 9: Pull partition images
# =============================================================================
# Each partition is read as a raw binary image.
# These serve as both backup AND source material for the Android 16 build.

# boot - Contains the Linux kernel and initial ramdisk
# Expected output:
#   /dev/block/by-name/boot: 1 file pulled, 0 skipped. 46.7 MB/s (67108864 bytes in 1.372s)
#   Size: 64MB exactly (0x4000000) - this is a fixed partition size
echo "==> Pulling boot partition (kernel + ramdisk, ~64MB) ..."
adb pull /dev/block/by-name/boot "$BACKUP_DIR/boot.img"

# dtbo - Device Tree Blob Overlay, hardware-specific overrides applied at boot
# Expected output:
#   /dev/block/by-name/dtbo: 1 file pulled, 0 skipped. 42.6 MB/s (4194304 bytes in 0.094s)
#   Size: 4MB exactly (0x400000)
echo "==> Pulling dtbo partition (device tree overlays, ~4MB) ..."
adb pull /dev/block/by-name/dtbo "$BACKUP_DIR/dtbo.img"

# uboot - U-Boot bootloader, first stage boot code after ROM
# Expected output:
#   /dev/block/by-name/uboot: 1 file pulled, 0 skipped. 37.1 MB/s (4194304 bytes in 0.108s)
#   Size: 4MB exactly (0x400000)
echo "==> Pulling uboot partition (bootloader, ~4MB) ..."
adb pull /dev/block/by-name/uboot "$BACKUP_DIR/uboot.img"

# trust - ARM TrustZone secure world firmware (handles secure boot, keys etc.)
# Expected output:
#   /dev/block/by-name/trust: 1 file pulled, 0 skipped. 34.6 MB/s (4194304 bytes in 0.116s)
#   Size: 4MB exactly (0x400000)
echo "==> Pulling trust partition (TrustZone / ARM trusted firmware, ~4MB) ..."
adb pull /dev/block/by-name/trust "$BACKUP_DIR/trust.img"

# vbmeta - Android Verified Boot metadata, contains hashes of other partitions
# Expected output:
#   /dev/block/by-name/vbmeta: 1 file pulled, 0 skipped. 34.3 MB/s (1048576 bytes in 0.029s)
#   Size: 1MB exactly (0x100000)
echo "==> Pulling vbmeta partition (verified boot metadata, ~1MB) ..."
adb pull /dev/block/by-name/vbmeta "$BACKUP_DIR/vbmeta.img"

# recovery - Recovery OS, used for factory reset and sideloading updates
# Expected output:
#   /dev/block/by-name/recovery: 1 file pulled, 0 skipped. 50.5 MB/s (100663296 bytes in 1.902s)
#   Size: 96MB exactly (0x6000000)
echo "==> Pulling recovery partition (~96MB) ..."
adb pull /dev/block/by-name/recovery "$BACKUP_DIR/recovery.img"

# baseparameter - Rockchip-specific partition storing display and hardware parameters
# Expected output:
#   /dev/block/by-name/baseparameter: 1 file pulled, 0 skipped. 14.7 MB/s (1048576 bytes in 0.068s)
#   Size: 1MB exactly (0x100000)
echo "==> Pulling baseparameter partition (~1MB) ..."
adb pull /dev/block/by-name/baseparameter "$BACKUP_DIR/baseparameter.img"

# =============================================================================
# STEP 10: Check super partition size before pulling
# =============================================================================
# Super is a large dynamic partition containing system, vendor, product
# and system_ext. We need it to extract proprietary vendor blobs.
#
# Expected output:
#   3263168512
#   Super partition size: 3263168512 bytes (~3.0GB)
#
# The number 3263168512 = exactly 3,112MB of allocated partition space
# (actual used content is less - system+vendor+product together ~2.3GB)
echo "==> Checking super partition size ..."
SUPER_SIZE=$(adb shell blockdev --getsize64 /dev/block/by-name/super)
SUPER_SIZE_GB=$(echo "scale=1; $SUPER_SIZE / 1073741824" | bc)
echo "Super partition size: $SUPER_SIZE bytes (~${SUPER_SIZE_GB}GB)"
echo ""

# super - Contains system + vendor + product as dynamic partitions (Android 10+ feature)
# Vendor blobs (GPU drivers, video decoders, WiFi firmware) live here.
# This is the largest partition and will take the longest to pull.
#
# Expected output:
#   /dev/block/by-name/super: 1 file pulled, 0 skipped. 67.1 MB/s (3263168512 bytes in 46.381s)
#
# Transfer time depends on connection speed:
#   - Gigabit Ethernet via ADB: ~45-60 seconds
#   - WiFi via ADB: ~3-5 minutes
echo "==> Pulling super partition (~${SUPER_SIZE_GB}GB, this will take a few minutes) ..."
adb pull /dev/block/by-name/super "$BACKUP_DIR/super.img"

# =============================================================================
# STEP 11: Verify backup completeness
# =============================================================================
# Expected output (file sizes should match approximately):
#
#   total ~3.3G
#   -rw-r--r-- 1 user user 1.0M baseparameter.img
#   -rw-r--r-- 1 user user  64M boot.img
#   -rw-r--r-- 1 user user 4.0M dtbo.img
#   -rw-r--r-- 1 user user  29K getprop_backup.txt
#   -rw-r--r-- 1 user user  96M recovery.img
#   -rw-r--r-- 1 user user 3.1G super.img
#   -rw-r--r-- 1 user user 4.0M trust.img
#   -rw-r--r-- 1 user user 4.0M uboot.img
#   -rw-r--r-- 1 user user 1.0M vbmeta.img
#   drwxr-xr-x 1 user user  ... device-tree-backup/
#
# If any file is missing or significantly smaller than expected,
# re-run the corresponding adb pull command above.
echo ""
echo "==> Backup complete! Verifying files ..."
ls -lh "$BACKUP_DIR/"

echo ""
echo "============================================================"
echo " Phase 1 Complete!"
echo "============================================================"
echo ""
echo " All files saved to: $BACKUP_DIR/"
echo ""
echo " What we extracted:"
echo "   boot.img            - Kernel + ramdisk"
echo "   dtbo.img            - Device tree overlays"
echo "   uboot.img           - Bootloader"
echo "   trust.img           - ARM TrustZone firmware"
echo "   vbmeta.img          - Verified boot metadata"
echo "   recovery.img        - Recovery OS"
echo "   baseparameter.img   - Rockchip display parameters"
echo "   super.img           - System + Vendor + Product partitions"
echo "   device-tree-backup/ - Full hardware device tree (3977 files)"
echo "   getprop_backup.txt  - All Android system properties"
echo ""
echo " IMPORTANT: Copy $BACKUP_DIR/ to a safe location before proceeding!"
echo " These files are your only way back to the original firmware."
echo ""
echo " Next: Boot your Ubuntu build machine and run Phase 2"
echo "       (Build environment setup)"
echo "============================================================"
