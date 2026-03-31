# aosp_x88pro.mk - X88 Pro Android TV Box
#
# Board: X88PRO-RK3566-4D32-V1.0
# SoC:   Rockchip RK3566

PRODUCT_NAME   := aosp_x88pro
PRODUCT_DEVICE := x88pro
PRODUCT_BRAND  := Android
PRODUCT_MODEL  := X88 Pro
PRODUCT_MANUFACTURER := Rockchip
PRODUCT_CHARACTERISTICS := tv

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)

# Disable kernel VINTF requirements enforcement.
# The Rockchip BSP kernel (5.10) predates FCM 6 hardening requirements:
#   - CONFIG_DEVMEM=y (BSP needs /dev/mem; FCM 6 requires =n)
#   - CONFIG_TRACE_GPU_MEM not present in BSP defconfig
# Engineering build only — not required for device bring-up.
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

# Enable dynamic partitions — required to assemble super.img from the
# individual partition images (system, vendor, product, odm, system_ext).
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# =============================================================================
# Vendor prebuilt ELF modules (binaries + shared libraries)
# =============================================================================
# Android 16 requires ELF prebuilts to be declared in Android.bp rather than
# PRODUCT_COPY_FILES. All modules below are defined in Android.bp.
# Non-ELF files (firmware, configs, .rc) remain in PRODUCT_COPY_FILES below.
# =============================================================================
PRODUCT_PACKAGES += \
    libGLES_mali \
    android.hardware.graphics.allocator@4.0-impl-bifrost \
    android.hardware.graphics.mapper@4.0-impl-bifrost \
    vulkan.rk356x \
    hwcomposer.rk30board \
    hw_output.default \
    rockchip.hardware.outputmanager@1.0-impl \
    libbaseparameter \
    audio.primary.rk30board \
    libmpp \
    libomxvpu_dec \
    libomxvpu_enc \
    librga \
    bcmdhd.ko \
    dhd_static_buf.ko \
    libbt-vendor \
    android.hardware.bluetooth@1.0-service \
    android.hardware.keymaster@4.0-service.optee \
    android.hardware.gatekeeper@1.0-service.optee \
    android.hardware.weaver@1.0-impl \
    libRkkeymaster4 \
    libwvhidl \
    libwvdrmengine \
    android.hardware.drm@1.3-service.widevine \
    memtrack.rk356x \
    android.hardware.power-service.rockchip \
    android.hardware.lights-service.rockchip \
    hdmi_cec.rk356x \
    librknnrt \
    rknn_server \
    rockchip.hardware.neuralnetworks@1.0-impl \
    rockchip.hardware.neuralnetworks@1.0-service \
    libdrm

# =============================================================================
# WiFi: AP6398S (bcmdhd out-of-tree driver)
# =============================================================================
# Firmware and nvram are non-ELF — stay in PRODUCT_COPY_FILES
# bcmdhd.ko is declared in Android.bp (prebuilt_etc) and in PRODUCT_PACKAGES
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcm4359c0_ag.bin \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag_apsta.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcm4359c0_ag_apsta.bin \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag_p2p.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcm4359c0_ag_p2p.bin \
    device/rockchip/x88pro/proprietary/firmware/nvram_ap6398s.txt:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/nvram_ap6398s.txt \
    device/rockchip/x88pro/proprietary/firmware/nvram_ap6398sa.txt:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/nvram_ap6398sa.txt

# bcmdhd reads generic firmware paths configured in kernel config and BoardConfig.
# PRODUCT_SYMLINKS is not a real build variable — use PRODUCT_COPY_FILES with
# generic destination names instead (copies, not symlinks, but functionally identical).
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcmdhd.bin \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag_apsta.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcmdhd_apsta.bin \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag_p2p.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcmdhd_p2p.bin \
    device/rockchip/x88pro/proprietary/firmware/nvram_ap6398s.txt:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/nvram.txt

# =============================================================================
# Bluetooth: AP6398S firmware (non-ELF)
# =============================================================================
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/firmware/BCM4359C0.hcd:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/BCM4359C0.hcd

# =============================================================================
# HAL service init scripts
# =============================================================================
# Vendor prebuilt service binaries do not have embedded init.rc (unlike AOSP
# source-built binaries). Without these, HAL services never start at boot.
#
# init.bcmdhd.rc: preloads dhd_static_buf.ko before WiFi HAL calls insmod
#   on bcmdhd.ko. wifi_load_driver() uses finit_module(2) directly — no
#   kernel dependency resolution — so dhd_static_buf must already be loaded.
#
# Note: tee-supplicant binary is absent from the stock vendor dump, so its
#   .rc is not installed. keymaster@4.0-service.optee will fail TEE ops on
#   first boot; this is acceptable since no PIN/password is set on a fresh
#   install.
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/init.bcmdhd.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.bcmdhd.rc \
    device/rockchip/x88pro/proprietary/etc/init/android.hardware.bluetooth@1.0-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.bluetooth@1.0-service.rc \
    device/rockchip/x88pro/proprietary/etc/init/android.hardware.keymaster@4.0-service.optee.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.keymaster@4.0-service.optee.rc \
    device/rockchip/x88pro/proprietary/etc/init/android.hardware.gatekeeper@1.0-service.optee.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.gatekeeper@1.0-service.optee.rc \
    device/rockchip/x88pro/proprietary/etc/init/android.hardware.drm@1.3-service.widevine.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.drm@1.3-service.widevine.rc \
    device/rockchip/x88pro/proprietary/etc/init/power-aidl-rockchip.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/power-aidl-rockchip.rc \
    device/rockchip/x88pro/proprietary/etc/init/lights-rockchip.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/lights-rockchip.rc \
    device/rockchip/x88pro/proprietary/etc/init/rockchip.hardware.neuralnetworks@1.0-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/rockchip.hardware.neuralnetworks@1.0-service.rc

# =============================================================================
# NPU: RKNN server init script (non-ELF)
# =============================================================================
# Maintained in device tree (not proprietary/) since it's a config file
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/init.rknn_server.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.rknn_server.rc

# =============================================================================
# System properties
# =============================================================================
PRODUCT_PROPERTY_OVERRIDES += \
    wifi.interface=wlan0 \
    wifi.supplicant_scan_interval=15 \
    ro.wifi.sleep.power.down=true \
    persist.wifi.sleep.delay.ms=0 \
    ro.config.media_vol_steps=25 \
    ro.sf.lcd_density=213 \
    debug.sf.enable_hwc_vds=1 \
    persist.sys.strictmode.disable=true \
    drm.service.enabled=true \
    media.stagefright.use-awesome=false

# =============================================================================
# Hardware feature declarations
# =============================================================================
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

# fstab - partition mount configuration
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/fstab.rk30board:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.rk30board \
    device/rockchip/x88pro/fstab.rk30board:$(TARGET_COPY_OUT_RAMDISK)/fstab.rk30board
