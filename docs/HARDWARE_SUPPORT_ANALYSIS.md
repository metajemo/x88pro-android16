# X88 Pro Hardware Support Analysis for Android 16

Research-based assessment of every hardware component and its expected
support status in our Android 16 build. Updated based on latest community
and upstream kernel research (March 2026).

---

## Summary Table

| Component | Chip/Driver | Android 16 Status | Source |
|---|---|---|---|
| CPU | Cortex-A55 / mainline | ✅ Full support | Mainline kernel |
| RAM / eMMC | LPDDR4 / eMMC 5.1 | ✅ Full support | Mainline kernel |
| Ethernet | GMAC / stmmac | ✅ Full support | Mainline kernel |
| USB | XHCI / dwc3 | ✅ Full support | Mainline kernel |
| HDMI output | VOP2 / dw-hdmi | ✅ Works via BSP kernel | Rockchip BSP |
| HDMI audio | dw-hdmi-audio | 🔧 PCM only, no passthrough | LibreELEC community |
| HDMI CEC | dw-hdmi-cec | 🔧 Should work, untested | LibreELEC community |
| GPU | Mali-G52 / libmali | 🔧 Blob works, Panfrost alternative | Rockchip libmali |
| WiFi | AP6398S / brcmfmac | 🔧 Mainline driver + firmware blobs | Mainline kernel |
| Bluetooth | AP6398S / btbcm | 🔧 Mainline driver + firmware blobs | Mainline kernel |
| Video decode | RKVDEC2 / MPP | 🔧 Via Rockchip MPP (BSP kernel) | Rockchip MPP |
| Video encode | RKVENC / MPP | 🔧 1080p60, via Rockchip MPP | Rockchip MPP |
| NPU | RKNPU / RKNN2 | 🔧 Open source kernel driver + RKNN2 SDK | Rockchip RKNN2 |
| IR remote | SARADC / gpio-keys | 🔧 Likely works, needs DTS config | Device tree |
| Audio (HDMI) | dw-hdmi-audio | 🔧 PCM only | LibreELEC community |
| Audio (SPDIF) | rk-spdif | 🔧 Driver exists, needs config | Rockchip BSP |
| AV1 decode | — | ❌ Not supported by RK3566 VPU | Hardware limitation |
| HDR | — | ❌ Not supported by RK3566 | Hardware limitation |
| HDMI audio passthrough | — | ❌ DD/DTS passthrough not available | LibreELEC community |

---

## Detailed Analysis Per Component

### ✅ CPU — ARM Cortex-A55 (Full support)
Four Cortex-A55 cores are fully supported in mainline Linux and Android.
No action needed beyond standard kernel config.

**Android 16 impact:** None — works out of the box.

---

### ✅ Ethernet — Synopsys GMAC (Full support)
The `stmmac` driver for Synopsys GMAC (`snps,dwmac-4.20a`) is fully
mainlined and very well tested. Our DTS node `ethernet@fe010000` with
compatible `rockchip,rk3568-gmac` is supported.

**Android 16 impact:** None — works out of the box with correct DTS.

---

### ✅ USB — XHCI / DWC3 (Full support)
Standard USB controllers fully supported in mainline Linux and Android.
Multiple USB host controllers and OTG are present in the device tree.

**Android 16 impact:** None — works out of the box.

---

### 🔧 HDMI Output — VOP2 / dw-hdmi (Works via BSP kernel)
HDMI output works well via Rockchip's BSP kernel (5.10). We will use
the BSP kernel rather than mainline for our Android 16 build, which is
standard practice for Android on Rockchip devices.

**Key finding:** The LibreELEC community has confirmed HDMI output working
on RK3566 with the BSP kernel. The VOP2 display controller and dw-hdmi
driver are both included in Rockchip's BSP kernel tree.

**Android 16 impact:** Need to use Rockchip BSP kernel 5.10 (not mainline).
This is already our plan — AOSP Android 16 with Rockchip's BSP kernel.

---

### 🔧 HDMI Audio (PCM only, no passthrough)
HDMI audio works but with important limitations confirmed by the LibreELEC
community who have tested this exact hardware:
- **PCM stereo audio:** ✅ Works
- **Dolby Digital (DD) passthrough:** ❌ Not available
- **DTS passthrough:** ❌ Not available
- **Multi-channel LPCM:** Unknown

**Android 16 impact:** Standard stereo audio will work. Users expecting
Dolby/DTS passthrough for a home theater setup will be disappointed.
This is a known hardware/driver limitation, not something we can fix in
the build.

**Phase 3 action:** Configure HDMI audio HAL for PCM output only.

---

### 🔧 HDMI CEC (Should work)
The `dw-hdmi-cec` driver supports Consumer Electronics Control (CEC),
which allows TV remotes to control the box. The LibreELEC community
reports CEC should work on RK3566 devices, though it's sensitive to
TV compatibility and HDMI cable quality.

**Android 16 impact:** Standard Android TV CEC functionality should work.
Worth testing after initial boot — if it doesn't work it's likely a DTS
configuration issue.

---

### 🔧 GPU — Mali-G52 / libmali blob (Works with blob)
The Mali-G52 GPU has two driver options:

**Option 1 — libmali blob (recommended for Android):**
Rockchip provides a proprietary `libmali` userspace driver that supports:
- OpenGL ES 1.1 / 2.0 / 3.2
- OpenCL 2.0
- Vulkan 1.1

This is what Android expects and what we extract from the Android 11
vendor partition. Android's graphics stack (gralloc, HWC) is designed
to work with the Mali blob.

**Option 2 — Panfrost (open source, Linux-oriented):**
The open source Panfrost driver works on Mali-G52 but is primarily
designed for Linux desktop (DRM/KMS). Getting it working with Android's
graphics stack is significantly more complex and not recommended for
our initial build.

**Key finding:** libmali version compatibility matters. The Mali-G52
requires specific libmali variants (`g13p0` or `g2p0`). Version mismatches
cause boot failures or rendering glitches. We should verify the exact
libmali version from our Android 11 extraction.

**Android 16 impact:** Use libmali blob from Android 11 vendor partition.
May need to source a newer libmali version if Android 11 blob is
incompatible with Android 16 gralloc HAL.

**Phase 3 action:** Extract and verify libmali version. Source updated
blob from Rockchip's libmali repository if needed.

---

### 🔧 WiFi — AMPAK AP6398S / brcmfmac (Mainline driver, needs firmware)
The `brcmfmac` driver for Broadcom/AMPAK WiFi modules is fully mainlined.

**What works:**
- Driver: `brcmfmac` in mainline kernel ✅
- WiFi 5 (802.11ac) connectivity ✅
- Hotspot (AP) mode ✅

**What we need to provide:**
- `fw_bcm43598a3.bin` — STA firmware
- `fw_bcm43598a3_apsta.bin` — AP firmware
- `nvram_ap6398s.txt` — board-specific calibration data

These are extracted from our Android 11 vendor partition in Phase 3.

**Android 16 impact:** WiFi should work after placing firmware files in
the correct vendor firmware path.

---

### 🔧 Bluetooth — AMPAK AP6398S / btbcm (Mainline driver, needs firmware)
Same chip as WiFi (BCM43598). Bluetooth 5.0 via UART interface.

**What we need:**
- `BCM43598A3.hcd` — BT firmware file (from Android 11 vendor)
- Correct UART configuration in device tree

**Android 16 impact:** BT should work after placing firmware in correct path.

---

### 🔧 Hardware Video Decode — RKVDEC2 / Rockchip MPP
This is one of the more complex components. The RK3566 uses the second
generation Rockchip video decoder called **rkvdec2**.

**Critical finding:** There is NO mainline Linux kernel driver for rkvdec2.
The mainline rkvdec driver only covers the first generation (RK3399/RK3328).
Collabora is working on VDPU346 support for RK356X but it's not merged yet.

**Supported codecs via Rockchip MPP (BSP kernel):**
- H.264: ✅ Up to 4K@60fps
- H.265 (HEVC): ✅ Up to 4K@60fps
- VP9: ✅ Up to 4K@60fps
- AV1: ❌ NOT supported by RK3566 hardware
- 10-bit (HDR): ⚠️ Decode works but HDR tone-mapping not supported

**Approach:** Use Rockchip's BSP kernel (5.10) with MPP library.
Rockchip MPP explicitly supports RK3566/RK3568 and is the standard
approach for Android video acceleration on this SoC.

**Android 16 impact:** Video decode requires Rockchip MPP library
(`librockchip_mpp.so`) and BSP kernel. Extract from Android 11 vendor
partition and include in our build.

**Phase 3 action:** Extract MPP library from vendor partition. Add MPP
HAL configuration to device tree.

---

### 🔧 Hardware Video Encode — RKVENC / Rockchip MPP
H.264 and H.265 encoding up to 1080p@60fps via RKVENC hardware.
Also handled by Rockchip MPP library.

**Android 16 impact:** Same as video decode — needs MPP library.
Encoding is less critical for a TV box (primarily used for recording).

---

### 🔧 NPU — Rockchip RKNPU / RKNN2 (Open source kernel driver)
As researched previously:
- Kernel driver (`rknpu`): Open source, in Rockchip kernel tree ✅
- Runtime: RKNN2 SDK (`librknnrt.so`) — sourced from Rockchip GitHub
- Android HAL interfaces: Compatible with Android 16 standard HALs

**Phase 3 action:** Download RKNN2 runtime via `phase3-npu-blobs` target.

---

### 🔧 IR Remote Control (Likely works, needs DTS config)
The device tree shows `adc-keys` and `saradc@fe720000` which suggests
IR input is handled via ADC-connected buttons or a dedicated IR receiver.

**Android 16 impact:** Standard Android remote control functionality
should work with correct DTS configuration. The exact IR receiver chip
needs to be identified from the PCB or device tree.

**Phase 3 action:** Examine `adc-keys` device tree node for key mappings.
Configure Android key layout file for the remote control.

---

### ❌ AV1 Decode (Hardware limitation — not fixable)
The RK3566 VPU does not support AV1 hardware decode. This is a chip
hardware limitation. AV1 content can still play via software decode
but will use significant CPU resources.

**Android 16 impact:** YouTube and other streaming services increasingly
use AV1. Performance on AV1 content will be poor (software decode only).

---

### ❌ HDR (Hardware limitation — not fixable)
The RK3566 does not support HDR10 or Dolby Vision display output.
HDR content will be tone-mapped to SDR automatically.

**Android 16 impact:** Content will play but without HDR color quality.

---

## Phase Impact Summary

### Phase 3 additions needed:

| Addition | Why |
|---|---|
| Extract `librockchip_mpp.so` from vendor | Hardware video decode/encode |
| Extract `libmali.so` and verify version | GPU rendering |
| Verify libmali version compatibility | Prevent boot/render failures |
| Add MPP HAL config to device tree | Video acceleration |
| Configure `adc-keys` DTS node | IR remote control |
| Configure HDMI audio for PCM only | Audio output |
| Download RKNN2 runtime | NPU support |

### Phase 4 additions needed:

| Addition | Why |
|---|---|
| Use Rockchip BSP kernel 5.10 (not mainline) | HDMI, video decode, GPU |
| Enable `brcmfmac` in kernel config | WiFi |
| Enable `rknpu` in kernel config | NPU kernel driver |
| Configure gralloc HAL for libmali | GPU/display pipeline |
| Add MPP kernel config | Video acceleration |

### Known limitations (cannot be fixed):
- No AV1 hardware decode
- No HDR display output
- No Dolby/DTS audio passthrough (PCM only)
