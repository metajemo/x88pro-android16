# X88 Pro Hardware Support Analysis

Hardware: X88PRO-RK3566-4D32-V1.0  
SoC: Rockchip RK3566 (4x Cortex-A55 @ 1.8GHz, Mali-G52 2EE, RKNPU 0.8 TOPS)  
RAM: 8GB LPDDR4  
Storage: 128GB eMMC  
Stock OS: Android 11 (SDK 30, kernel 4.19.172)

---

## Quick Reference Table

| Component | Driver / Blob | Status | Notes |
|---|---|---|---|
| CPU (4x Cortex-A55) | mainline | ✅ Full | ARM64, all 4 cores |
| RAM (8GB LPDDR4) | mainline | ✅ Full | ~7.5GB usable |
| eMMC (128GB) | mainline | ✅ Full | mmcblk2 |
| USB 2.0/3.0 | mainline | ✅ Full | Host + OTG |
| SD card slot | `dw_mmc` (mainline) | ✅ Full | `fe2b0000.dwmmc`, vold managed, auto-format |
| Ethernet (GMAC) | stmmac (mainline) | ✅ Full | Gigabit, `snps,dwmac-4.20a` |
| HDMI output | BSP kernel VOP2 | ✅ Via BSP | Requires Rockchip BSP kernel 5.10 |
| HDMI CEC | dw-hdmi-cec + `hdmi_cec.rk356x.so` | ✅ Confirmed | Blob confirmed in vendor partition |
| HDMI audio | dw-hdmi-audio | ⚠️ Partial | PCM stereo only — no DD/DTS passthrough |
| GPU Mali-G52 | libmali blob (Bifrost) | 🔧 Blob required | `libGLES_mali.so` + gralloc bifrost HAL |
| Vulkan 1.1 | libmali blob | 🔧 Blob required | `vulkan.rk356x.so` confirmed |
| OpenCL 2.0 | libmali blob | 🔧 Blob required | Via `libGLES_mali.so` |
| HWComposer | `hwcomposer.rk30board.so` | 🔧 Blob required | Display composition HAL |
| WiFi (AP6398S) | **bcmdhd (out-of-tree!)** | 🔧 Blob + module | NOT brcmfmac — see WiFi section |
| Bluetooth (AP6398S) | btbcm (mainline) | 🔧 Firmware blob | BT 5.0, `BCM4359C0.hcd` confirmed |
| Video decode H264/H265/VP9 | Rockchip MPP (BSP) | 🔧 Blob + BSP | `libmpp.so` — rkvdec2 no mainline driver |
| Video encode H264/H265 | Rockchip MPP (BSP) | 🔧 Blob + BSP | `libomxvpu_enc.so` |
| 2D acceleration | `librga.so` | 🔧 Blob required | RGA scaling/rotation/color conversion |
| Audio output | `audio.primary.rk30board.so` | 🔧 Blob required | HDMI PCM stereo |
| USB audio | `audio.usb.default.so` | 🔧 Blob required | USB DAC/headset support |
| Keymaster / Security | OP-TEE (TrustZone) | 🔧 Blob required | Keymaster 4.0 via `trust.img` BL32 |
| Gatekeeper | OP-TEE (TrustZone) | 🔧 Blob required | Screen lock backed by TrustZone |
| Widevine DRM | L3 software DRM | ⚠️ L3 only | Streaming works — SD quality for DRM content |
| NPU (RKNPU 0.8 TOPS) | RKNN2 v1.6.0 | 🔧 RKNN2 only | Android 11 RKNN v1 blobs incompatible |
| Power management | `power-service.rockchip` | 🔧 Blob required | CPU scaling, thermal management |
| Lights / LED | `lights-service.rockchip` | 🔧 Blob required | Power indicator LED |
| Health HAL | `android.hardware.health@2.0-impl` | 🔧 Blob required | Battery/power state reporting |
| Memory tracking | `memtrack.rk356x.so` | 🔧 Blob required | `adb shell dumpsys meminfo` |
| Neural Networks HAL | `rockchip.hardware.neuralnetworks` | 🔧 Blob required | Android NNAPI → RKNPU bridge |
| AV1 decode | — | ❌ Not supported | RK3566 hardware limitation |
| HDR display | — | ❌ Not supported | RK3566 hardware limitation |
| Audio passthrough | — | ❌ Not supported | Hardware limitation (PCM only) |
| Widevine L1 | — | ❌ Not supported | No secure video path on this hardware |

**Legend:** ✅ Works | ⚠️ Partial | 🔧 Requires proprietary blob/BSP | ❌ Not possible

---

## Component Details

### CPU / RAM / Storage / USB / Ethernet
Fully supported by mainline Linux and AOSP. No special configuration needed.

- CPU: 4x ARM Cortex-A55 @ 1.8GHz, ARMv8-A, 39-bit VA, 4K pages
- RAM: 8GB LPDDR4 (confirmed via ADB: MemTotal 7860196 kB)
- eMMC: 128GB (mmcblk2, confirmed partition layout in Phase 1)
- Ethernet: Synopsys GMAC (`snps,dwmac-4.20a`), `stmmac` mainline driver, Gigabit

---

### GPU: Mali-G52 2EE (Bifrost architecture)

**Status: 🔧 Proprietary blob required**

The Mali-G52 is a Bifrost-architecture GPU. Android requires ARM's proprietary
libmali blob — open source Panfrost is not compatible with Android's gralloc HAL.

**Confirmed blobs extracted from Phase 3:**

| Blob | Size | Purpose |
|---|---|---|
| `lib64/egl/libGLES_mali.so` | ~38MB | Main driver (OpenGL ES 3.2, OpenCL 2.0) |
| `lib64/hw/vulkan.rk356x.so` | ~38MB | Vulkan 1.1 ICD |
| `lib64/hw/hwcomposer.rk30board.so` | ~1MB | Hardware Composer HAL |
| `lib64/hw/hw_output.default.so` | varies | Display output manager |
| `lib64/hw/rockchip.hardware.outputmanager@1.0-impl.so` | varies | Rockchip output manager HAL |
| `lib64/hw/android.hardware.graphics.allocator@4.0-impl-bifrost.so` | ~70KB | gralloc allocator |
| `lib64/hw/android.hardware.graphics.mapper@4.0-impl-bifrost.so` | ~140KB | gralloc mapper |
| `lib64/libdrm.so` | varies | DRM (Direct Rendering Manager) library |
| `lib64/libbaseparameter.so` | varies | Rockchip display calibration parameters |

The `bifrost` suffix in the gralloc HAL confirms Mali-G52 belongs to the Bifrost
GPU family (G51, G52, G71, G72, G76).

**Important:** libmali version must match the BSP kernel's Mali driver version.
Version mismatch causes black screen or rendering glitches.

---

### HDMI

**Output: ✅ Via BSP kernel**  
**CEC: ✅ Confirmed**  
**Audio: ⚠️ PCM stereo only**

HDMI output requires the Rockchip BSP kernel for VOP2 (Video Output Processor 2).

HDMI CEC confirmed via `hdmi_cec.rk356x.so` and `android.hardware.tv.cec@1.0-impl.so`
in the vendor partition. Allows TV remote to control the box.

HDMI audio: PCM stereo only. Dolby Digital / DTS bitstream passthrough is a
hardware limitation of this board's audio path — cannot be fixed in software.

---

### Audio

**Status: 🔧 Proprietary blob required**

| Blob | Purpose |
|---|---|
| `lib64/hw/audio.primary.rk30board.so` | Primary HDMI audio HAL |
| `lib64/hw/audio.r_submix.default.so` | Remote submix (screen recording audio) |
| `lib64/hw/audio.usb.default.so` | USB audio devices (DAC, headset) |
| `lib64/hw/android.hardware.audio@6.0-impl.so` | Audio HIDL HAL |
| `lib64/hw/android.hardware.audio.effect@6.0-impl.so` | Audio effects HAL |

---

### WiFi: AMPAK AP6398S (BCM4359c0)

**Status: 🔧 Out-of-tree kernel module + firmware blobs required**

> ⚠️ **IMPORTANT CORRECTION (discovered Phase 3):**
> This device uses Broadcom's proprietary `bcmdhd` out-of-tree driver,
> NOT the `brcmfmac` mainline driver. Confirmed by finding `bcmdhd.ko`
> in `/vendor/lib/modules/` and kernel config `CONFIG_BCMDHD=y`.

**Chip identification:**
- Module: AMPAK AP6398S
- Silicon: BCM43598 (marketing) = BCM4359 revision c0
- WiFi 5 (802.11ac), dual-band 2.4GHz + 5GHz

**Kernel config (extracted from stock boot.img):**
```
CONFIG_BCMDHD=y
CONFIG_BCMDHD_FW_PATH="/vendor/etc/firmware/fw_bcmdhd.bin"
CONFIG_BCMDHD_NVRAM_PATH="/vendor/etc/firmware/nvram.txt"
```

**Required files:**

| File | Location | Purpose |
|---|---|---|
| `bcmdhd.ko` | `vendor/lib/modules/` | WiFi kernel module |
| `fw_bcm4359c0_ag.bin` | `vendor/etc/firmware/` | STA firmware |
| `fw_bcm4359c0_ag_apsta.bin` | `vendor/etc/firmware/` | AP/hotspot firmware |
| `fw_bcm4359c0_ag_p2p.bin` | `vendor/etc/firmware/` | P2P/WiFi Direct firmware |
| `nvram_ap6398s.txt` | `vendor/etc/firmware/` | RF calibration |

**Firmware symlinks required** (bcmdhd uses generic paths):
```
/vendor/etc/firmware/fw_bcmdhd.bin     → fw_bcm4359c0_ag.bin
/vendor/etc/firmware/fw_bcmdhd_apsta.bin → fw_bcm4359c0_ag_apsta.bin
/vendor/etc/firmware/nvram.txt          → nvram_ap6398s.txt
```

---

### Bluetooth: AMPAK AP6398S (BCM4359c0) BT 5.0

**Status: 🔧 Firmware blob required**

Uses `btbcm` mainline kernel driver. BT 5.0 confirmed via `BCM4359C0.hcd`.

| Blob | Purpose |
|---|---|
| `BCM4359C0.hcd` | BT controller init firmware |
| `lib64/hw/android.hardware.bluetooth@1.0-impl.so` | BT HAL implementation |
| `lib64/libbt-vendor.so` | BT vendor library |

---

### Video Decode/Encode: Rockchip MPP

**Status: 🔧 Proprietary blob + BSP kernel required**

The RK3566 uses `rkvdec2` — **no mainline kernel driver exists**. BSP kernel 5.10 required.

| Blob | Size | Purpose |
|---|---|---|
| `lib64/libmpp.so` | ~6.3MB | MPP main library |
| `lib64/libomxvpu_dec.so` | varies | OMX decode wrapper |
| `lib64/libomxvpu_enc.so` | varies | OMX encode wrapper |
| `lib64/librga.so` | ~112KB | 2D acceleration |

**Supported codecs:**

| Codec | Decode | Encode | Max |
|---|---|---|---|
| H.264 | ✅ Hardware | ✅ Hardware | 4K@60fps / 1080p@60fps |
| H.265 | ✅ Hardware | ✅ Hardware | 4K@60fps / 1080p@60fps |
| VP9 | ✅ Hardware | ❌ | 4K@60fps |
| AV1 | ❌ | ❌ | Hardware limitation |

---

### Security: Keymaster 4.0 + Gatekeeper (OP-TEE)

**Status: 🔧 Proprietary blobs required**

The RK3566 uses OP-TEE (Open Portable Trusted Execution Environment) running
in TrustZone (ARM Secure World) for hardware-backed security operations.

OP-TEE is loaded as BL32 in `trust.img` during early boot — this is why
`trust.img` must be preserved from the original device.

**What this enables:**
- Screen lock with hardware-backed credential storage
- Encrypted storage (FDE/FBE)
- App key attestation
- Basic SafetyNet (without Play Integrity certification)

| Blob | Purpose |
|---|---|
| `bin/hw/android.hardware.keymaster@4.0-service.optee` | Keymaster service (OP-TEE) |
| `bin/hw/android.hardware.gatekeeper@1.0-service.optee` | Gatekeeper service (OP-TEE) |
| `lib64/hw/android.hardware.weaver@1.0-impl.so` | Weaver HAL (credential storage) |
| `lib64/libRkkeymaster4.so` | Rockchip Keymaster 4 library |
| `lib64/libkeymaster4support.so` | Keymaster support library |

---

### Widevine DRM

**Status: ⚠️ L3 software DRM only**

Widevine L3 is present and functional — streaming apps (Netflix, Disney+, etc.)
will work. However content is limited to SD quality for DRM-protected streams
because L1 hardware DRM is not available on this device.

**Why no L1:** Widevine L1 requires a secure video path — hardware that can
decrypt and decode content entirely within the secure world without exposing
unencrypted frames to the normal world. The RK3566 in this TV box configuration
does not have this capability certified by Google.

| Blob | Purpose |
|---|---|
| `lib/mediadrm/libwvdrmengine.so` | Widevine L3 DRM engine |
| `lib/libwvhidl.so` | Widevine HIDL library |
| `bin/hw/android.hardware.drm@1.3-service.widevine` | Widevine DRM service |
| `bin/hw/android.hardware.drm@1.3-service.clearkey` | ClearKey DRM service |

---

### NPU: RKNPU (0.8 TOPS)

**Status: 🔧 RKNN2 runtime required**

The stock Android 11 RKNN v1 runtime is **incompatible** with Android 16 HALs.
RKNN2 v1.6.0 is used instead, downloaded from `rockchip-linux/rknn-toolkit2`.

Note: `CONFIG_RKNPU` was NOT enabled in the stock Android 11 kernel — the NPU
was unused in the original firmware. We enable it in our BSP kernel config.

| Blob | Purpose |
|---|---|
| `lib64/librknnrt.so` | RKNN2 inference runtime (~5.9MB) |
| `bin/rknn_server` | NPU inference server daemon |
| `lib64/hw/rockchip.hardware.neuralnetworks@1.0-impl.so` | NNAPI → RKNPU bridge |

---

### System HALs

**Power management:**  
`android.hardware.power-service.rockchip` — CPU frequency scaling (EAS/HMP),
wake lock management, thermal throttling.

**Lights:**  
`android.hardware.lights-service.rockchip` — controls the power indicator LED
on the front of the X88 Pro box.

**Health:**  
`android.hardware.health@2.0-impl-2.1.so` — reports power state to Android.
Since the box is always plugged in, this reports AC charging permanently.

**Memory tracking:**  
`memtrack.rk356x.so` — allows `adb shell dumpsys meminfo` and memory pressure
reporting to work correctly.

---

## What Requires the BSP Kernel

The following **require** the Rockchip BSP kernel (5.10) and will **not work**
with the AOSP GKI (Generic Kernel Image):

- HDMI output (VOP2 display controller driver)
- Hardware video decode/encode (rkvdec2 — no mainline driver)
- Mali-G52 GPU kernel driver (pairs with libmali blob)
- bcmdhd WiFi kernel module (out-of-tree, must build against BSP)
- RKNPU kernel driver (not in stock kernel, must enable in BSP config)

BSP kernel: `github.com/rockchip-linux/kernel` branch `develop-5.10`  
Base defconfig: `rockchip_defconfig` (1050 entries, Android-oriented)

---

## Known Hardware Limitations

These are physical hardware constraints that cannot be fixed in software:

- ❌ **AV1 decode** — VPU does not support AV1
- ❌ **HDR display** — Display controller lacks HDR metadata pipeline
- ❌ **Audio bitstream passthrough** — No Dolby Digital / DTS hardware path
- ❌ **Widevine L1** — No secure video path / Google certification
- ❌ **4K@60fps WiFi** — AP6398S is WiFi 5 (802.11ac), not WiFi 6

---

## Phase 3 Blob Extraction Summary

All blobs extracted from X88 Pro Android 11 vendor partition (`super.img`).

**Extraction pipeline:**
```
super.img → simg2img → raw → lpunpack → vendor.img → debugfs → files
```

**Partition layout confirmed (from lpunpack --info):**
```
system:     ~1.08GB  (sectors 2048-2264304)
system_ext: ~50MB    (sectors 2265088-2367840)
vendor:     ~493MB   (sectors 2369536-3378664)
product:    ~750MB   (sectors 3379200-4932080)
odm:        ~600KB   (sectors 4933632-4934856)
```

**Complete blob inventory (52 files):**

```
proprietary/
├── modules/
│   └── bcmdhd.ko                    (2.1MB)  WiFi kernel module
├── firmware/
│   ├── fw_bcm4359c0_ag.bin          (640KB)  WiFi STA
│   ├── fw_bcm4359c0_ag_apsta.bin    (640KB)  WiFi AP
│   ├── fw_bcm4359c0_ag_p2p.bin      (627KB)  WiFi P2P
│   ├── nvram_ap6398s.txt            (6KB)    WiFi calibration
│   ├── nvram_ap6398sa.txt           (6KB)    WiFi calibration alt
│   └── BCM4359C0.hcd                         BT 5.0 firmware
├── lib64/
│   ├── egl/
│   │   └── libGLES_mali.so          (38MB)   Mali GPU driver
│   ├── hw/
│   │   ├── android.hardware.audio@6.0-impl.so
│   │   ├── android.hardware.audio.effect@6.0-impl.so
│   │   ├── android.hardware.bluetooth@1.0-impl.so
│   │   ├── android.hardware.graphics.allocator@4.0-impl-bifrost.so
│   │   ├── android.hardware.graphics.mapper@4.0-impl-bifrost.so
│   │   ├── android.hardware.health@2.0-impl-2.1.so
│   │   ├── android.hardware.memtrack@1.0-impl.so
│   │   ├── android.hardware.tv.cec@1.0-impl.so
│   │   ├── android.hardware.weaver@1.0-impl.so
│   │   ├── audio.primary.rk30board.so
│   │   ├── audio.r_submix.default.so
│   │   ├── audio.usb.default.so
│   │   ├── hdmi_cec.rk356x.so
│   │   ├── hwcomposer.rk30board.so
│   │   ├── hw_output.default.so
│   │   ├── memtrack.rk356x.so
│   │   ├── rockchip.hardware.neuralnetworks@1.0-impl.so
│   │   ├── rockchip.hardware.outputmanager@1.0-impl.so
│   │   └── vulkan.rk356x.so
│   ├── libbaseparameter.so
│   ├── libbt-vendor.so
│   ├── libdrm.so
│   ├── libkeymaster4support.so
│   ├── libmpp.so                    (6.3MB)  Video MPP
│   ├── librga.so                    (112KB)  2D accel
│   ├── libomxvpu_dec.so             OMX video decode
│   ├── libomxvpu_enc.so             OMX video encode
│   ├── libRkkeymaster4.so
│   └── librknnrt.so                 (5.9MB)  RKNN2 NPU runtime
├── lib/
│   ├── libwvhidl.so                 Widevine HIDL
│   └── mediadrm/
│       └── libwvdrmengine.so        Widevine L3 engine
├── bin/
│   ├── android.hardware.audio.service
│   ├── android.hardware.bluetooth@1.0-service
│   ├── android.hardware.drm@1.3-service.clearkey
│   ├── android.hardware.drm@1.3-service.widevine
│   ├── android.hardware.gatekeeper@1.0-service.optee
│   ├── android.hardware.health@2.1-service
│   ├── android.hardware.keymaster@4.0-service.optee
│   ├── android.hardware.lights-service.rockchip
│   ├── android.hardware.media.omx@1.0-service
│   ├── android.hardware.power-service.rockchip
│   ├── android.hardware.tv.cec@1.0-service
│   ├── move_widevine_data.sh
│   ├── rknn_server                  (883KB)  NPU daemon
│   └── rockchip.hardware.neuralnetworks@1.0-service
└── etc/
    └── init.rknn_server.rc
```

**Run extraction:**
```bash
./scripts/phase3_device_prep.sh extract-blobs backup/super.img \
    device/rockchip/x88pro/proprietary

./scripts/phase3_device_prep.sh npu-blobs \
    device/rockchip/x88pro/proprietary
```
