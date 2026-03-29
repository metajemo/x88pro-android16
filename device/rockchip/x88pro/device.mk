# device.mk - X88 Pro Android TV Box
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

# =============================================================================
# GPU: Mali-G52 Bifrost
# =============================================================================
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/lib64/egl/libGLES_mali.so:$(TARGET_COPY_OUT_VENDOR)/lib64/egl/libGLES_mali.so \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.graphics.allocator@4.0-impl-bifrost.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.graphics.allocator@4.0-impl-bifrost.so \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.graphics.mapper@4.0-impl-bifrost.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.graphics.mapper@4.0-impl-bifrost.so \
    device/rockchip/x88pro/proprietary/lib64/hw/vulkan.rk356x.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/vulkan.rk356x.so \
    device/rockchip/x88pro/proprietary/lib64/hw/hwcomposer.rk30board.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/hwcomposer.rk30board.so \
    device/rockchip/x88pro/proprietary/lib64/hw/hw_output.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/hw_output.default.so \
    device/rockchip/x88pro/proprietary/lib64/hw/rockchip.hardware.outputmanager@1.0-impl.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/rockchip.hardware.outputmanager@1.0-impl.so \
    device/rockchip/x88pro/proprietary/lib64/libdrm.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libdrm.so \
    device/rockchip/x88pro/proprietary/lib64/libbaseparameter.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbaseparameter.so

# =============================================================================
# Audio HAL
# =============================================================================
# PCM stereo only - no Dolby/DTS passthrough (hardware limitation)
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/lib64/hw/audio.primary.rk30board.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/audio.primary.rk30board.so \
    device/rockchip/x88pro/proprietary/lib64/hw/audio.r_submix.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/audio.r_submix.default.so \
    device/rockchip/x88pro/proprietary/lib64/hw/audio.usb.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/audio.usb.default.so \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.audio@6.0-impl.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.audio@6.0-impl.so \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.audio.effect@6.0-impl.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.audio.effect@6.0-impl.so \
    device/rockchip/x88pro/proprietary/bin/android.hardware.audio.service:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.audio.service

# =============================================================================
# Video: Rockchip MPP + OMX
# =============================================================================
# rkvdec2 requires BSP kernel 5.10 - NO mainline driver exists
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/lib64/libmpp.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmpp.so \
    device/rockchip/x88pro/proprietary/lib64/libomxvpu_dec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libomxvpu_dec.so \
    device/rockchip/x88pro/proprietary/lib64/libomxvpu_enc.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libomxvpu_enc.so \
    device/rockchip/x88pro/proprietary/lib64/librga.so:$(TARGET_COPY_OUT_VENDOR)/lib64/librga.so \
    device/rockchip/x88pro/proprietary/bin/android.hardware.media.omx@1.0-service:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.media.omx@1.0-service

# =============================================================================
# WiFi: AP6398S (bcmdhd out-of-tree driver)
# =============================================================================
# Uses bcmdhd NOT brcmfmac (discovered Phase 3)
# Firmware in /vendor/etc/firmware/ with generic symlinks
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/modules/bcmdhd.ko:$(TARGET_COPY_OUT_VENDOR)/lib/modules/bcmdhd.ko \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcm4359c0_ag.bin \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag_apsta.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcm4359c0_ag_apsta.bin \
    device/rockchip/x88pro/proprietary/firmware/fw_bcm4359c0_ag_p2p.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcm4359c0_ag_p2p.bin \
    device/rockchip/x88pro/proprietary/firmware/nvram_ap6398s.txt:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/nvram_ap6398s.txt \
    device/rockchip/x88pro/proprietary/firmware/nvram_ap6398sa.txt:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/nvram_ap6398sa.txt

# bcmdhd reads generic paths - symlink to real AP6398S files
PRODUCT_SYMLINKS += \
    /vendor/etc/firmware/fw_bcmdhd.bin:/vendor/etc/firmware/fw_bcm4359c0_ag.bin \
    /vendor/etc/firmware/fw_bcmdhd_apsta.bin:/vendor/etc/firmware/fw_bcm4359c0_ag_apsta.bin \
    /vendor/etc/firmware/fw_bcmdhd_p2p.bin:/vendor/etc/firmware/fw_bcm4359c0_ag_p2p.bin \
    /vendor/etc/firmware/nvram.txt:/vendor/etc/firmware/nvram_ap6398s.txt

# =============================================================================
# Bluetooth: AP6398S (BCM4359c0) BT 5.0
# =============================================================================
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/firmware/BCM4359C0.hcd:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/BCM4359C0.hcd \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.bluetooth@1.0-impl.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.bluetooth@1.0-impl.so \
    device/rockchip/x88pro/proprietary/lib64/libbt-vendor.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbt-vendor.so \
    device/rockchip/x88pro/proprietary/bin/android.hardware.bluetooth@1.0-service:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.bluetooth@1.0-service

# =============================================================================
# Security: Keymaster 4.0 + Gatekeeper (OP-TEE / TrustZone)
# =============================================================================
# Runs in TrustZone secure world via trust.img (BL32 / OP-TEE)
# Required for: screen lock, encrypted storage, app attestation
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/bin/android.hardware.keymaster@4.0-service.optee:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.keymaster@4.0-service.optee \
    device/rockchip/x88pro/proprietary/bin/android.hardware.gatekeeper@1.0-service.optee:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.gatekeeper@1.0-service.optee \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.weaver@1.0-impl.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.weaver@1.0-impl.so \
    device/rockchip/x88pro/proprietary/lib64/libRkkeymaster4.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libRkkeymaster4.so \
    device/rockchip/x88pro/proprietary/lib64/libkeymaster4support.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libkeymaster4support.so

# =============================================================================
# Widevine DRM L3
# =============================================================================
# L3 (software DRM) - streaming apps work but SD quality for DRM content
# L1 (hardware DRM) NOT available - no secure video path on this hardware
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/lib/libwvhidl.so:$(TARGET_COPY_OUT_VENDOR)/lib/libwvhidl.so \
    device/rockchip/x88pro/proprietary/lib/mediadrm/libwvdrmengine.so:$(TARGET_COPY_OUT_VENDOR)/lib/mediadrm/libwvdrmengine.so \
    device/rockchip/x88pro/proprietary/bin/android.hardware.drm@1.3-service.widevine:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.drm@1.3-service.widevine \
    device/rockchip/x88pro/proprietary/bin/android.hardware.drm@1.3-service.clearkey:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.drm@1.3-service.clearkey \
    device/rockchip/x88pro/proprietary/bin/move_widevine_data.sh:$(TARGET_COPY_OUT_VENDOR)/bin/move_widevine_data.sh

# =============================================================================
# Health HAL + Memory tracking
# =============================================================================
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.health@2.0-impl-2.1.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.health@2.0-impl-2.1.so \
    device/rockchip/x88pro/proprietary/bin/android.hardware.health@2.1-service:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.health@2.1-service \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.memtrack@1.0-impl.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.memtrack@1.0-impl.so \
    device/rockchip/x88pro/proprietary/lib64/hw/memtrack.rk356x.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/memtrack.rk356x.so

# =============================================================================
# Power HAL + Lights HAL
# =============================================================================
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/bin/android.hardware.power-service.rockchip:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.power-service.rockchip \
    device/rockchip/x88pro/proprietary/bin/android.hardware.lights-service.rockchip:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.lights-service.rockchip

# =============================================================================
# HDMI CEC
# =============================================================================
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/lib64/hw/android.hardware.tv.cec@1.0-impl.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.tv.cec@1.0-impl.so \
    device/rockchip/x88pro/proprietary/lib64/hw/hdmi_cec.rk356x.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/hdmi_cec.rk356x.so \
    device/rockchip/x88pro/proprietary/bin/android.hardware.tv.cec@1.0-service:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.tv.cec@1.0-service

# =============================================================================
# NPU: RKNPU (RKNN2 v1.6.0)
# =============================================================================
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/lib64/librknnrt.so:$(TARGET_COPY_OUT_VENDOR)/lib64/librknnrt.so \
    device/rockchip/x88pro/proprietary/bin/rknn_server:$(TARGET_COPY_OUT_VENDOR)/bin/rknn_server \
    device/rockchip/x88pro/proprietary/etc/init.rknn_server.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.rknn_server.rc \
    device/rockchip/x88pro/proprietary/lib64/hw/rockchip.hardware.neuralnetworks@1.0-impl.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/rockchip.hardware.neuralnetworks@1.0-impl.so \
    device/rockchip/x88pro/proprietary/bin/rockchip.hardware.neuralnetworks@1.0-service:$(TARGET_COPY_OUT_VENDOR)/bin/hw/rockchip.hardware.neuralnetworks@1.0-service

# =============================================================================
# WiFi config files
# =============================================================================
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/proprietary/etc/wifi/wpa_supplicant.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant.conf \
    device/rockchip/x88pro/proprietary/etc/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf \
    device/rockchip/x88pro/proprietary/etc/wifi/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf

# =============================================================================
# System properties
# =============================================================================
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.board=rk3566 \
    ro.board.platform=rk3566 \
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
# SD card: /devices/platform/fe2b0000.dwmmc/mmc_host* -> sdcard1:auto
# userdata: F2FS with AES-256 inline encryption
# Also handles USB storage, zram swap
PRODUCT_COPY_FILES += \
    device/rockchip/x88pro/fstab.rk30board:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.rk30board \
    device/rockchip/x88pro/fstab.rk30board:$(TARGET_COPY_OUT_RAMDISK)/fstab.rk30board
