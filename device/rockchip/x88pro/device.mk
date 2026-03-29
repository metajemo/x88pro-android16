# device.mk - X88 Pro Android TV Box
#
# Declares all files, packages and properties to include in the build.
# This is the main "recipe" that assembles the Android image.
#
# Board: X88PRO-RK3566-4D32-V1.0
# SoC:   Rockchip RK3566

# --- Product identity --------------------------------------------------------
PRODUCT_NAME   := aosp_x88pro
PRODUCT_DEVICE := x88pro
PRODUCT_BRAND  := Android
PRODUCT_MODEL  := X88 Pro
PRODUCT_MANUFACTURER := Rockchip

PRODUCT_CHARACTERISTICS := tv

# Inherit AOSP base TV configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)

# --- Device Tree Blob --------------------------------------------------------
# Our custom DTS for the X88 Pro based on rk3566-box-demo-v10 reference.
# Compiled during kernel build using cpp + dtc with BSP kernel headers.
# See: device/rockchip/x88pro/dts/rk3566-x88pro.dts
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/dts/rk3566-x88pro.dts:$(TARGET_COPY_OUT_VENDOR)/etc/rk3566-x88pro.dts

# --- GPU: Mali-G52 (libmali blob) --------------------------------------------
# The Mali-G52 requires ARM's proprietary libmali blob.
# Panfrost (open source) is NOT compatible with Android's gralloc HAL.
#
# libGLES_mali.so provides: OpenGL ES 3.2, Vulkan 1.1, OpenCL 2.0
# gralloc bifrost HAL: memory allocation for GPU buffers
# hwcomposer: display composition (used by SurfaceFlinger)
#
# IMPORTANT: Extract these from your device first:
#   ./scripts/phase3_device_prep.sh extract-blobs backup/super.img \
#       device/rockchip/x88pro/proprietary
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/lib64/egl/libGLES_mali.so:$(TARGET_COPY_OUT_VENDOR)/lib64/egl/libGLES_mali.so \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.graphics.allocator@4.0-impl-bifrost.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.graphics.allocator@4.0-impl-bifrost.so \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.graphics.mapper@4.0-impl-bifrost.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.graphics.mapper@4.0-impl-bifrost.so \
    device/rockchip/x88pro/proprietary/lib64/hw/vulkan.rk356x.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/vulkan.rk356x.so \
    device/rockchip/x88pro/proprietary/lib64/hw/hwcomposer.rk30board.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/hwcomposer.rk30board.so

# --- Video: Rockchip MPP -----------------------------------------------------
# libmpp.so provides hardware H.264/H.265/VP9 decode/encode via rkvdec2.
# rkvdec2 has NO mainline kernel driver - BSP kernel required.
# Without MPP all video plays in software (very slow on Cortex-A55).
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/lib64/libmpp.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmpp.so \
    device/rockchip/x88pro/proprietary/lib64/libomxvpu_dec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libomxvpu_dec.so \
    device/rockchip/x88pro/proprietary/lib64/libomxvpu_enc.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libomxvpu_enc.so \
    device/rockchip/x88pro/proprietary/lib64/librga.so:$(TARGET_COPY_OUT_VENDOR)/lib64/librga.so

# --- WiFi: AP6398S (bcmdhd driver) ------------------------------------------
# The X88 Pro uses Broadcom's proprietary bcmdhd out-of-tree WiFi driver.
# bcmdhd.ko must be compiled against the BSP kernel (5.10).
#
# IMPORTANT firmware path note:
# bcmdhd uses generic paths set at kernel config time:
#   CONFIG_BCMDHD_FW_PATH="/vendor/etc/firmware/fw_bcmdhd.bin"
#   CONFIG_BCMDHD_NVRAM_PATH="/vendor/etc/firmware/nvram.txt"
# We create symlinks to the actual AP6398S files.
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/modules/bcmdhd.ko:$(TARGET_COPY_OUT_VENDOR)/lib/modules/bcmdhd.ko \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcm4359c0_ag.bin \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag_apsta.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcm4359c0_ag_apsta.bin \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag_p2p.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcm4359c0_ag_p2p.bin \
    device/rockchip/x88pro/proprietary/firmware/nvram_ap6398s.txt:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/nvram_ap6398s.txt \
    device/rockchip/x88pro/proprietary/firmware/nvram_ap6398sa.txt:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/nvram_ap6398sa.txt

# WiFi firmware symlinks (bcmdhd reads generic paths, symlinked to real files)
# fw_bcmdhd.bin     -> fw_bcm4359c0_ag.bin      (STA mode)
# fw_bcmdhd_apsta.bin -> fw_bcm4359c0_ag_apsta.bin (AP mode)
# fw_bcmdhd_p2p.bin -> fw_bcm4359c0_ag_p2p.bin  (P2P mode)
# nvram.txt         -> nvram_ap6398s.txt          (RF calibration)
PRODUCT_SYMLINKS += \
    /vendor/etc/firmware/fw_bcmdhd.bin:/vendor/etc/firmware/fw_bcm4359c0_ag.bin \
    /vendor/etc/firmware/fw_bcmdhd_apsta.bin:/vendor/etc/firmware/fw_bcm4359c0_ag_apsta.bin \
    /vendor/etc/firmware/fw_bcmdhd_p2p.bin:/vendor/etc/firmware/fw_bcm4359c0_ag_p2p.bin \
    /vendor/etc/firmware/nvram.txt:/vendor/etc/firmware/nvram_ap6398s.txt

# --- Bluetooth: AP6398S (BCM4359c0) ------------------------------------------
# BT 5.0. btbcm mainline driver loads HCD firmware at init.
# BCM4359C0.hcd contains the BT controller initialization firmware.
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/firmware/BCM4359C0.hcd:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/BCM4359C0.hcd

# --- NPU: RKNPU (RKNN2 runtime) ----------------------------------------------
# 0.8 TOPS NPU. Android 11 RKNN v1 is incompatible with Android 16.
# RKNN2 v1.6.0 downloaded from rockchip-linux/rknn-toolkit2.
#
# Run first: ./scripts/phase3_device_prep.sh npu-blobs
#
# rknn_server runs as a system daemon, accepting inference requests
# over a socket from app processes.
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/lib64/librknnrt.so:$(TARGET_COPY_OUT_VENDOR)/lib64/librknnrt.so \
    device/rockchip/x88pro/proprietary/bin/rknn_server:$(TARGET_COPY_OUT_VENDOR)/bin/rknn_server \
    device/rockchip/x88pro/proprietary/etc/init.rknn_server.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.rknn_server.rc

# --- HAL configuration files -------------------------------------------------
# These were extracted from the stock vendor partition.
# They configure audio routing, media codecs, WiFi supplicant etc.
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/etc/wifi/wpa_supplicant.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant.conf \
    device/rockchip/x88pro/proprietary/etc/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf \
    device/rockchip/x88pro/proprietary/etc/wifi/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf

# --- System properties -------------------------------------------------------
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.board=rk3566 \
    ro.board.platform=rk3566 \
    \
    wifi.interface=wlan0 \
    wifi.supplicant_scan_interval=15 \
    ro.wifi.sleep.power.down=true \
    persist.wifi.sleep.delay.ms=0 \
    \
    ro.config.media_vol_steps=25 \
    ro.config.notification_sound=Tethys.ogg \
    ro.config.alarm_alert=Oxygen.ogg \
    \
    ro.sf.lcd_density=213 \
    \
    debug.sf.enable_hwc_vds=1 \
    \
    persist.sys.strictmode.disable=true

# --- Features ----------------------------------------------------------------
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.ethernet.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.ethernet.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version.xml \
    frameworks/native/data/etc/android.software.vulkan.deqp.level-2020-03-01.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.vulkan.deqp.level.xml

# --- Stock kernel config (reference for Phase 4 kernel build) ----------------
# Extracted from boot.img during Phase 1. Documents exactly what was
# enabled in the Android 11 stock kernel. Used as reference when
# configuring our BSP 5.10 kernel build in Phase 4.
# NOT copied to the device image - build reference only.
