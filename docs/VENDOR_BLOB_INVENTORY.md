# Vendor Blob Inventory — X88 Pro Android 16

This document categorizes every vendor component by its source and why
it's needed. This is the definitive reference for understanding what
goes into the build and where it comes from.

---

## Category 1: Built from AOSP Source ✅
*These are built by the AOSP build system from open source code.
No vendor blobs needed. AOSP version is always preferred.*

| Component | AOSP Module | Notes |
|---|---|---|
| ClearKey DRM | `frameworks/av/drm/mediadrm/plugins/clearkey` | AIDL v1, newer than vendor HIDL |
| Audio HIDL HAL | `hardware/interfaces/audio` | `android.hardware.audio@6.0-impl` |
| Audio Effect HAL | `hardware/interfaces/audio/effect` | `android.hardware.audio.effect@6.0-impl` |
| Audio USB | `hardware/libhardware/modules/usbaudio` | `audio.usb.default` |
| Audio R-Submix | `frameworks/av/services/audiopolicy` | `audio.r_submix.default` |
| Bluetooth HAL | `hardware/interfaces/bluetooth` | `android.hardware.bluetooth@1.0-impl` |
| Health HAL | `hardware/interfaces/health` | `android.hardware.health@2.0-impl-2.1` |
| Memtrack HAL | `hardware/interfaces/memtrack` | `android.hardware.memtrack@1.0-impl` |
| TV CEC HAL | `hardware/interfaces/tv/cec` | `android.hardware.tv.cec@1.0-impl` |
| Keymaster support | `system/keymaster` | `libkeymaster4support` |
| libdrm | `external/libdrm` | Standard DRM library |
| Audio service | `frameworks/av` | `android.hardware.audio.service` |
| Media OMX service | `frameworks/av/media/libstagefright` | `android.hardware.media.omx@1.0-service` |
| Bluetooth service | `system/bt` | `android.hardware.bluetooth@1.0-service` |
| Health service | `hardware/interfaces/health` | `android.hardware.health@2.1-service` |
| TV CEC service | `hardware/interfaces/tv/cec` | `android.hardware.tv.cec@1.0-service` |
| WiFi configs | `frameworks/opt/net/wifi` | `wpa_supplicant.conf` etc. |

---

## Category 2: Extracted from Stock Android 11 Vendor 🔧
*Proprietary blobs extracted from the X88 Pro stock firmware.
Required because no open source alternative exists for Android.*

### GPU — ARM Mali-G52 (Bifrost)
ARM proprietary driver. Panfrost (open source) is NOT compatible
with Android's gralloc HAL.

| Blob | Purpose |
|---|---|
| `lib64/egl/libGLES_mali.so` | OpenGL ES 3.2 + OpenCL 2.0 driver |
| `lib64/hw/vulkan.rk356x.so` | Vulkan 1.1 ICD |
| `lib64/hw/hwcomposer.rk30board.so` | Hardware Composer HAL |
| `lib64/hw/hw_output.default.so` | Display output manager |
| `lib64/hw/rockchip.hardware.outputmanager@1.0-impl.so` | Rockchip output HAL |
| `lib64/hw/android.hardware.graphics.allocator@4.0-impl-bifrost.so` | gralloc allocator |
| `lib64/hw/android.hardware.graphics.mapper@4.0-impl-bifrost.so` | gralloc mapper |
| `lib64/libbaseparameter.so` | Rockchip display calibration |

### Audio — Rockchip HDMI Audio
Board-specific audio routing for HDMI PCM output.

| Blob | Purpose |
|---|---|
| `lib64/hw/audio.primary.rk30board.so` | HDMI PCM audio HAL |

### Video — Rockchip MPP (Media Process Platform)
rkvdec2 has NO mainline kernel driver. BSP kernel + MPP required.

| Blob | Purpose |
|---|---|
| `lib64/libmpp.so` | H.264/H.265/VP9 decode/encode |
| `lib64/libomxvpu_dec.so` | OMX video decode wrapper |
| `lib64/libomxvpu_enc.so` | OMX video encode wrapper |
| `lib64/librga.so` | 2D acceleration (scaling, rotation) |

### WiFi — AMPAK AP6398S (BCM4359c0)
bcmdhd out-of-tree driver + Broadcom proprietary firmware.

| Blob | Purpose |
|---|---|
| `modules/bcmdhd.ko` | WiFi kernel module (rebuilt against BSP) |
| `firmware/fw_bcm4359c0_ag.bin` | WiFi STA firmware |
| `firmware/fw_bcm4359c0_ag_apsta.bin` | WiFi AP/hotspot firmware |
| `firmware/fw_bcm4359c0_ag_p2p.bin` | WiFi P2P firmware |
| `firmware/nvram_ap6398s.txt` | RF calibration data |
| `firmware/nvram_ap6398sa.txt` | RF calibration data (alt) |

### Bluetooth — AMPAK AP6398S (BCM4359c0) BT 5.0

| Blob | Purpose |
|---|---|
| `firmware/BCM4359C0.hcd` | BT controller init firmware |
| `lib64/libbt-vendor.so` | BT vendor library |

### Security — OP-TEE / TrustZone (Keymaster 4.0)
Tied to the specific `trust.img` on this device.

| Blob | Purpose |
|---|---|
| `bin/android.hardware.keymaster@4.0-service.optee` | Keymaster service |
| `bin/android.hardware.gatekeeper@1.0-service.optee` | Gatekeeper service |
| `lib64/hw/android.hardware.weaver@1.0-impl.so` | Weaver HAL |
| `lib64/libRkkeymaster4.so` | Rockchip Keymaster 4 library |

### Display / System HALs

| Blob | Purpose |
|---|---|
| `lib64/hw/hdmi_cec.rk356x.so` | HDMI CEC driver |
| `lib64/hw/memtrack.rk356x.so` | Memory tracking |
| `bin/android.hardware.power-service.rockchip` | Power/thermal HAL |
| `bin/android.hardware.lights-service.rockchip` | LED/lights HAL |

### Widevine DRM L3
Google-provisioned per device. L3 = software DRM (SD quality only).
L1 hardware DRM not available on this hardware.

| Blob | Purpose |
|---|---|
| `lib/libwvhidl.so` | Widevine HIDL library |
| `lib/mediadrm/libwvdrmengine.so` | Widevine L3 DRM engine |
| `bin/android.hardware.drm@1.3-service.widevine` | Widevine DRM service |

---

## Category 3: Downloaded from Rockchip Official SDK 📥
*Not from the device — downloaded fresh from Rockchip's GitHub.
Used because the Android 11 version is incompatible with Android 16.*

### RKNN2 NPU Runtime (v1.6.0)
Source: `github.com/rockchip-linux/rknn-toolkit2`

| Blob | Purpose |
|---|---|
| `lib64/librknnrt.so` | RKNN2 inference runtime |
| `bin/rknn_server` | NPU inference server daemon |
| `etc/init.rknn_server.rc` | Service startup script |
| `lib64/hw/rockchip.hardware.neuralnetworks@1.0-impl.so` | NNAPI → RKNPU bridge |
| `bin/rockchip.hardware.neuralnetworks@1.0-service` | Neural networks service |

---

## Category 4: Built from BSP Kernel Source 🔨
*Kernel modules built from Rockchip's BSP kernel source.
Cannot use prebuilt — must match kernel version exactly.*

| Component | Source | Notes |
|---|---|---|
| `bcmdhd.ko` | BSP kernel `drivers/net/wireless/rockchip_wlan/rkwifi` | Rebuilt against BSP 5.10 |

---

## Summary

| Category | Count | Source |
|---|---|---|
| Built from AOSP source | 18 | `android-16.0.0_r1` |
| Extracted from stock vendor | 34 | X88 Pro Android 11 (2022) |
| Downloaded from Rockchip SDK | 5 | `rknn-toolkit2` v1.6.0 |
| Built from BSP kernel | 1 | `rockchip-linux/kernel develop-5.10` |
| **Total** | **58** | |

---

## Legal Notes

- **AOSP components** — Apache 2.0 / GPL (open source)
- **ARM Mali blobs** — ARM proprietary, no redistribution
- **Broadcom WiFi/BT** — Broadcom proprietary, no redistribution
- **Rockchip MPP/HALs** — Rockchip proprietary, no redistribution
- **Widevine** — Google proprietary, device-specific, no redistribution
- **RKNN2 runtime** — Rockchip proprietary, no redistribution

All proprietary blobs must be extracted from your own device.
See `scripts/phase3_device_prep.sh extract-blobs` for extraction.
