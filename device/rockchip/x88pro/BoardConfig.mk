# BoardConfig.mk - X88 Pro Android TV Box
#
# Low-level board configuration for the AOSP build system.
# Defines kernel, partition layout, bootloader, and hardware config.
#
# Board: X88PRO-RK3566-4D32-V1.0
# SoC:   Rockchip RK3566 (4x Cortex-A55, Mali-G52 2EE)
# RAM:   8GB LPDDR4
# eMMC:  128GB

# --- Architecture ------------------------------------------------------------
TARGET_ARCH         := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI      := arm64-v8a
TARGET_CPU_VARIANT  := cortex-a55

# 32-bit compatibility (for 32-bit apps)
TARGET_2ND_ARCH         := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI      := armeabi-v7a
TARGET_2ND_CPU_ABI2     := armeabi
TARGET_2ND_CPU_VARIANT  := cortex-a55

# --- Kernel ------------------------------------------------------------------
# Using Rockchip BSP kernel 5.10 (required for VOP2 HDMI, rkvdec2, Mali-G52)
# Mainline GKI kernel does NOT support these components.
#
# BSP kernel source: github.com/rockchip-linux/kernel branch develop-5.10
# Base defconfig:    rockchip_defconfig
# Our overlay:       device/rockchip/x88pro/kernel-config-x88pro.config
#
# Stock kernel info (extracted from boot.img Phase 1):
#   Version: 4.19.172 (Android 11)
#   We are upgrading to: 5.10.x (BSP for Android 16)

TARGET_KERNEL_SOURCE := kernel/rockchip-bsp
TARGET_KERNEL_CONFIG := rockchip_defconfig
TARGET_KERNEL_CONFIG_OVERLAYS := \
    device/rockchip/x88pro/kernel-config-x88pro.config

TARGET_KERNEL_ARCH     := arm64
TARGET_KERNEL_CLANG_COMPILE := true

BOARD_KERNEL_BASE        := 0x00200000
BOARD_KERNEL_PAGESIZE    := 4096
BOARD_KERNEL_OFFSET      := 0x00008000
BOARD_RAMDISK_OFFSET     := 0x01000000
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
BOARD_DTB_OFFSET         := 0x00f00000

# Kernel command line
# Confirmed from running device (Phase 1 extraction)
BOARD_KERNEL_CMDLINE := \
    console=ttyFIQ0 \
    androidboot.console=ttyFIQ0 \
    androidboot.hardware=rk30board \
    androidboot.selinux=permissive \
    init=/init \
    earlycon=uart8250,mmio32,0xfe660000 \
    rootwait \
    ro

# --- Bootloader / Partitions -------------------------------------------------
# Partition layout confirmed from Phase 1 extraction (gdisk output)
# eMMC device: mmcblk2
#
# Partition map:
#   mmcblk2p1  uboot      4MB
#   mmcblk2p2  trust      4MB
#   mmcblk2p3  misc       4MB
#   mmcblk2p4  dtbo       4MB
#   mmcblk2p5  vbmeta     1MB
#   mmcblk2p6  boot       64MB
#   mmcblk2p7  recovery   96MB
#   mmcblk2p8  baseparameter 1MB
#   mmcblk2p9  super      3.1GB  (system + vendor + product + odm)
#   mmcblk2p10 userdata   rest   (~111GB)

TARGET_NO_BOOTLOADER := true
TARGET_NO_RECOVERY   := false

BOARD_USES_METADATA_PARTITION := true

# Super partition (dynamic partitions)
# Total super size confirmed from partition table (Phase 1)
BOARD_SUPER_PARTITION_SIZE             := 3263168512  # ~3.1GB
BOARD_SUPER_PARTITION_GROUPS           := rockchip_dynamic_partitions
BOARD_ROCKCHIP_DYNAMIC_PARTITIONS_SIZE := 3258974208  # max group size
BOARD_ROCKCHIP_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    system_ext \
    vendor \
    product \
    odm

# Individual partition sizes (approximate, based on stock)
BOARD_SYSTEMIMAGE_PARTITION_SIZE       := 1291911168  # ~1.2GB (increased from 1.1GB — A16 system content ~1128MB)
BOARD_VENDORIMAGE_PARTITION_SIZE       := 515899392   # ~493MB
BOARD_PRODUCTIMAGE_PARTITION_SIZE      := 795017216   # ~750MB
BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE   := 52592640    # ~50MB
BOARD_ODMIMAGE_PARTITION_SIZE          := 4194304     # 4MB (increased from 612KB for precompiled_sepolicy)

BOARD_BOOTIMAGE_PARTITION_SIZE         := 67108864    # 64MB
BOARD_RECOVERYIMAGE_PARTITION_SIZE     := 100663296   # 96MB

# Partition file systems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE  := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE  := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE     := ext4

TARGET_COPY_OUT_VENDOR  := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_ODM     := odm

# --- DTBO --------------------------------------------------------------------
# Device tree blob overlay image, built from BSP kernel DTB via mkdtimg.
# Source DTB: kernel/rockchip-bsp/arch/arm64/boot/dts/rockchip/rk3566-box-demo-v10.dtb
# Rebuild command (run after kernel build):
#   aosp/prebuilts/misc/linux-x86/libufdt/mkdtimg create \
#     aosp/out/target/product/x88pro/dtbo.img --page_size=4096 \
#     kernel/rockchip-bsp/arch/arm64/boot/dts/rockchip/rk3566-box-demo-v10.dtb
BOARD_PREBUILT_DTBOIMAGE := device/rockchip/x88pro/prebuilt/dtbo.img
BOARD_DTBOIMG_PARTITION_SIZE := 4194304

# --- VINTF -------------------------------------------------------------------
# Vendor manifest: declares HALs provided by the vendor partition
DEVICE_MANIFEST_FILE := device/rockchip/x88pro/vintf/manifest.xml

# --- Display -----------------------------------------------------------------
# HDMI output via VOP2 (BSP kernel required)
# Resolution: up to 4K@60fps
TARGET_SCREEN_DENSITY := 213

# --- WiFi --------------------------------------------------------------------
# AP6398S (BCM4359c0) - bcmdhd out-of-tree driver
# Note: bcmdhd uses generic firmware paths, real files are symlinked:
#   /vendor/etc/firmware/fw_bcmdhd.bin -> fw_bcm4359c0_ag.bin
#   /vendor/etc/firmware/nvram.txt     -> nvram_ap6398s.txt
BOARD_WLAN_DEVICE           := bcmdhd
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
WPA_SUPPLICANT_VERSION      := VER_0_8_X
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_bcmdhd
BOARD_HOSTAPD_DRIVER        := NL80211
BOARD_HOSTAPD_PRIVATE_LIB   := lib_driver_cmd_bcmdhd
WIFI_DRIVER_MODULE_NAME     := bcmdhd
WIFI_DRIVER_MODULE_PATH     := /vendor/lib/modules/bcmdhd.ko
WIFI_DRIVER_FW_PATH_PARAM   := /sys/module/bcmdhd/parameters/firmware_path
WIFI_DRIVER_FW_PATH_STA     := /vendor/etc/firmware/fw_bcmdhd.bin
WIFI_DRIVER_FW_PATH_AP      := /vendor/etc/firmware/fw_bcmdhd_apsta.bin
WIFI_DRIVER_FW_PATH_P2P     := /vendor/etc/firmware/fw_bcmdhd_p2p.bin
WIFI_HIDL_FEATURE_DUAL_INTERFACE := true

# --- Bluetooth ---------------------------------------------------------------
# AP6398S (BCM4359c0) BT 5.0
# btbcm mainline driver loads BCM4359C0.hcd at init
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := \
    device/rockchip/x88pro/bluetooth

# --- SELinux -----------------------------------------------------------------
# Start permissive for initial bring-up, tighten later
BOARD_SEPOLICY_DIRS += device/rockchip/x88pro/sepolicy

# --- Verified Boot -----------------------------------------------------------
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3  # disable verification for dev

# --- Misc --------------------------------------------------------------------
TARGET_BOARD_PLATFORM := rk356x

# Use Clang for kernel compilation
TARGET_KERNEL_CLANG_COMPILE := true
