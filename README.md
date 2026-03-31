# Android 16 for X88 Pro (RK3566)

Community project to build and run Android 16 on the **X88 Pro** Android TV box powered by the **Rockchip RK3566** SoC.

> ⚠️ **Work in progress** — This project is actively being developed. Follow along or contribute!

---

## Device Specifications

| Component | Details |
|---|---|
| **Board** | X88PRO-RK3566-4D32-V1.0 |
| **SoC** | Rockchip RK3566 (4x ARM Cortex-A55 @ 1.8GHz) |
| **GPU** | ARM Mali-G52 2EE (Bifrost) — OpenGL ES 3.2, Vulkan 1.1, OpenCL 2.0 |
| **NPU** | Rockchip RKNPU — 0.8 TOPS (RKNN2 SDK) |
| **RAM** | 8GB LPDDR4 |
| **Storage** | 128GB eMMC 5.1 |
| **Ethernet** | Gigabit (Synopsys GMAC, `stmmac` driver — mainline) |
| **WiFi** | AMPAK AP6398S / Broadcom BCM4359c0 — WiFi 5, **`bcmdhd` driver (out-of-tree)** |
| **Bluetooth** | AMPAK AP6398S / Broadcom BCM4359c0 — BT 5.0, `btbcm` driver (mainline) |
| **Video out** | HDMI 2.0 (4K@60fps) |
| **Video decode** | H.264/H.265/VP9 up to 4K@60fps via Rockchip MPP (no AV1, no HDR) |
| **Video encode** | H.264/H.265 up to 1080p@60fps via Rockchip MPP |
| **Audio** | HDMI PCM stereo + SPDIF output (no DD/DTS passthrough) |
| **USB** | 1x USB-A 3.0 + 2x USB-A 2.0 + 1x USB-C OTG (power+data) |
| **Stock OS** | Android 11 (kernel 4.19.172, `userdebug` build) |

---

### Hardware Support Status

| Component | Status | Notes |
|---|---|---|
| CPU / RAM / Storage | ✅ Full | Mainline kernel |
| Ethernet | ✅ Full | `stmmac` driver, mainline |
| USB | ✅ Full | XHCI/DWC3, mainline |
| HDMI output | ✅ Full | Via Rockchip BSP kernel 5.10 (VOP2) |
| HDMI CEC | 🔧 Expected | `hdmi_cec.rk356x.so` confirmed in vendor |
| WiFi | 🔧 Required | `bcmdhd.ko` (out-of-tree) + `fw_bcm4359c0_ag*.bin` firmware |
| Bluetooth | 🔧 Required | `btbcm` mainline + `BCM4359C0.hcd` firmware |
| GPU | 🔧 Required | `libGLES_mali.so` blob + gralloc bifrost HAL |
| Vulkan 1.1 | 🔧 Required | `vulkan.rk356x.so` blob |
| Video decode (H.264/H.265/VP9) | 🔧 Required | `libmpp.so` + BSP kernel (rkvdec2) |
| Video encode | 🔧 Required | `libmpp.so` + OMX wrappers |
| NPU | 🔧 Required | RKNPU kernel driver + RKNN2 v1.6.0 runtime |
| HDMI audio (PCM) | 🔧 Expected | Stereo PCM only |
| SPDIF output | ✅ Mainline | `rockchip,rk3568-spdif` — no blobs needed |
| IR remote | 🔧 Likely | Needs DTS key mapping config |
| HDMI audio passthrough | ❌ Not possible | Hardware limitation |
| AV1 decode | ❌ Not possible | RK3566 VPU hardware limitation |
| HDR display | ❌ Not possible | RK3566 hardware limitation |

> ⚠️ **WiFi driver note:** Despite the AP6398S chipset having mainline `brcmfmac` support in theory,
> the X88 Pro BSP uses Broadcom's proprietary `bcmdhd` out-of-tree driver.
> `bcmdhd.ko` must be compiled against the BSP kernel. See
> [docs/HARDWARE_SUPPORT_ANALYSIS.md](docs/HARDWARE_SUPPORT_ANALYSIS.md) for details.

See [docs/HARDWARE_SUPPORT_ANALYSIS.md](docs/HARDWARE_SUPPORT_ANALYSIS.md) for full research details.

---

## Project Status

| Phase | Description | Status |
|---|---|---|
| Phase 1 | Device extraction & backup | ✅ Complete |
| Phase 2 | Build environment setup | ✅ Complete |
| Phase 3 | Device tree & vendor blobs | ✅ Complete |
| Phase 4 | Android 16 build | ✅ Complete |
| Phase 5 | Flash & verify | 🔜 Ready to flash |

---

## Prerequisites

### Build Machine
- Ubuntu 24.04 LTS (other distros may work but are untested)
- 16GB RAM minimum (32GB recommended)
- 250GB free disk space minimum (SSD strongly recommended)
- Fast internet connection for AOSP sync (~100GB download)

### Tools
- ADB (for device communication)
- `repo` tool (for AOSP source management)
- `dtc` (device tree compiler, for Phase 3)
- `simg2img` / `lpunpack` (for extracting super.img)
- `rkdeveloptool` (for flashing via Rockchip loader mode)

---

## Quick Start

### Phase 1 — Extract from your device (Windows/WSL or Linux)

> Run this **before** you do anything else. This backs up your original Android 11
> and extracts everything we need for the build.

```bash
# Clone this repo
git clone https://github.com/emiliyan.paunov/x88pro-android16.git
cd x88pro-android16

# Run extraction (replace IP with your box's IP address)
./scripts/phase1_extraction.sh 192.168.1.x
```

Expected result: a `backup/` folder containing:

```
backup/
├── boot.img            (64MB)  - Original kernel
├── dtbo.img            (4MB)   - Device tree overlays
├── uboot.img           (4MB)   - Bootloader
├── trust.img           (4MB)   - TrustZone firmware
├── vbmeta.img          (1MB)   - Verified boot metadata
├── recovery.img        (96MB)  - Recovery OS
├── baseparameter.img   (1MB)   - Rockchip display params
├── super.img           (3.1GB) - System + Vendor + Product
├── getprop_backup.txt          - All system properties
└── device-tree-backup/         - Full device tree (3977 files)
```

> 💾 **Back these files up somewhere safe.** They are your only way to restore
> the original Android 11 if something goes wrong.

---

### Phase 2 — Set up build environment (Ubuntu)

```bash
# Install all dependencies and sync AOSP source
./scripts/phase2_environment.sh

# Verify environment is ready
./scripts/phase2_environment.sh verify
```

Key facts about the build environment:
- AOSP branch: `android-16.0.0_r1` (stable Android 16, release `BP2A.250605.031.A2`)
- Java: must be version 17 (script pins this via `update-alternatives`)
- ccache: configured at 50GB (re-run after reboot to restore)
- Lunch target: `aosp_x88pro-bp2a-eng`

---

### Phase 3 — Prepare device tree and vendor blobs

```bash
# Extract device tree from boot.img
./scripts/phase3_device_prep.sh extract-dt backup/boot.img

# Extract vendor blobs from super.img
./scripts/phase3_device_prep.sh extract-blobs backup/super.img \
    device/rockchip/x88pro/proprietary

# Download RKNN2 NPU runtime (v1.6.0)
./scripts/phase3_device_prep.sh npu-blobs \
    device/rockchip/x88pro/proprietary
```

The script uses a **hybrid extraction approach** designed to work on X88 Pro
and other RK3566 TV boxes (H96 Max, X88 Pro 20, etc.) with different hardware:

**Phase A — Complete copy (~1169 files total):**
- `lib64/` — all 68 shared libraries (GPU, MPP, RGA, OMX, Keymaster, Widevine, WiFi, Camera, OpenCL, etc.)
- `lib/` — all 15 32-bit libraries (for 32-bit app compatibility)
- `bin/` — all 26 HAL service binaries
- `etc/` — all 1028 HAL config files (audio policy, media codecs, VINTF manifests, init scripts, etc.)

**Phase B — Hardware auto-detection:**
- WiFi chip detected from firmware filenames → copies only matching firmware
  - BCM4359c0 (AP6398S) — X88 Pro ✅ tested
  - BCM43456 (AP6256), BCM43455 (AP6255) — other RK3566 boxes
- BT firmware auto-detected from `BCM*.hcd` chip naming
- WiFi driver detected (bcmdhd out-of-tree vs brcmfmac mainline)
- Mali GPU version warning for BSP kernel compatibility check

> **Note on WiFi:** The X88 Pro uses Broadcom's proprietary `bcmdhd` out-of-tree
> driver. `bcmdhd.ko` must be rebuilt against the BSP kernel 5.10.

> **Note on video decode:** The RK3566 `rkvdec2` has no mainline kernel driver.
> BSP kernel 5.10 + `libmpp.so` is required. AV1 is not supported by the hardware.

> **Note on Widevine:** L3 (software) DRM is included — streaming apps work but
> DRM-protected content is limited to SD quality. L1 hardware DRM is not available.

---

### Phase 4 — Build Android 16

```bash
# Build the kernel first
cd kernel/rockchip-bsp
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j12 Image dtbs

# Then build AOSP (incremental — resumes from previous state)
cd ../../aosp
source build/envsetup.sh
lunch aosp_x88pro-bp2a-eng
m -j4

# Assemble super.img (dynamic partitions)
m superimage
```

Build output: `aosp/out/target/product/x88pro/` — see `docs/BUILD_INFO.md` for image sizes.
For build issues, see `docs/BUILD_TROUBLESHOOTING.md` (22 documented issues with fixes).

---

### Phase 5 — Flash to device

```bash
# Ensure rkdeveloptool is installed (built in Phase 2)
which rkdeveloptool

# Flash Android 16 to the device (device must be in loader mode)
./scripts/phase5_flash.sh flash aosp x88pro 192.168.1.213
```

> ⚠️ **Warning:** This replaces Android 11 with Android 16. Make sure Phase 1
> backup exists before flashing!

---

## Restoring Original Android 11

If anything goes wrong, you can restore the original firmware using the Phase 1 backup:

```bash
./scripts/phase5_flash.sh restore x88pro-backup
```

---

## How to Enable ADB on the X88 Pro

1. Go to **Settings → About Device**
2. Tap **Build Number** 7 times to enable Developer Options
3. Go to **Settings → Developer Options**
4. Enable **USB Debugging**
5. Enable **ADB over Network** (or connect via USB)
6. Note the IP address from **Settings → Network**

---

## Project Structure

```
x88pro-android16/
├── Makefile                        # Main build orchestration
├── README.md                       # This file
├── scripts/
│   ├── phase1_extraction.sh        # ADB extraction script
│   ├── phase2_environment.sh       # Build environment setup
│   ├── phase3_device_prep.sh       # Device tree + blob extraction
│   │                               #   extract-dt    - extract DTS from boot.img
│   │                               #   extract-blobs - extract vendor blobs
│   │                               #   npu-blobs     - download RKNN2 runtime
│   ├── phase4_build.sh             # AOSP + BSP kernel build
│   ├── phase5_flash.sh             # Flash Android 16 / restore Android 11
│   └── monitor_build.sh            # Build log monitor (success/failure detection)
├── device/
│   └── rockchip/
│       └── x88pro/
│           ├── AndroidProducts.mk  # Declares aosp_x88pro lunch target
│           ├── BoardConfig.mk      # Board config (partitions, kernel, WiFi)
│           ├── aosp_x88pro.mk      # Product definition (active — declared in AndroidProducts.mk)
│           ├── device.mk           # Legacy file — not included by build system
│           ├── kernel-config-stock.txt  # Stock kernel config (Phase 1 ref)
│           ├── dts/
│           │   ├── rk3566-x88pro.dts           # Our device tree source
│           │   └── rk3566-x88pro-decompiled.dts.ref  # Decompiled reference
│           └── proprietary/        # Vendor blobs (NOT in git - extract locally)
│               ├── lib64/          # GPU, MPP, RGA, RKNN2 libraries
│               ├── modules/        # bcmdhd.ko WiFi kernel module
│               ├── firmware/       # WiFi + BT firmware blobs
│               ├── bin/            # rknn_server daemon
│               └── etc/            # HAL configs, init scripts
├── kernel/
│   └── rockchip-bsp/               # BSP kernel (not in git - cloned by script)
│       └── ...                     # github.com/rockchip-linux/kernel develop-5.10
└── docs/
    ├── HARDWARE.md                 # Hardware specs and partition layout
    └── HARDWARE_SUPPORT_ANALYSIS.md # Per-component support status + research
```

---

## Contributing

This is a community project and contributions are very welcome!

**Ways to help:**
- Test builds and report issues
- Improve device tree entries
- Write documentation
- Help identify vendor blobs
- Port drivers from other RK3566 projects

**Related projects that helped:**
- [Rockchip Linux](https://github.com/rockchip-linux) — Official Rockchip kernel and manifests
- [Radxa Rock 3](https://github.com/radxa) — Another RK3566 board with good community support
- [LibreELEC RK356x](https://github.com/LibreELEC/LibreELEC.tv) — Linux for RK356x boxes
- [rknn-toolkit2](https://github.com/rockchip-linux/rknn-toolkit2) — RKNN2 NPU SDK

---

## License

Build scripts and device configuration files in this repository are released under the **Apache License 2.0**.

Android Open Source Project (AOSP) components are subject to their own licenses.

Proprietary vendor blobs extracted from the device are owned by Rockchip, ARM, and Broadcom
respectively — they are **not** included in this repository and must be extracted from your
own device using the Phase 3 script. You already own a license to run these blobs by virtue
of having purchased the device.

---


---

## ⚠️ Security Warning — BADBOX Malware

The **RockChip X88 Pro 10** is a confirmed BADBOX-infected device model
according to security researchers at EFF, Human Security, and TechCrunch (2023).
BADBOX is firmware-level botnet malware pre-installed by bad actors in the
supply chain. It silently proxies criminal traffic and performs ad fraud.

**Before running Phase 1:**
- Connect the box to an **isolated network** (not your main home network)
- Do **not** log into any accounts on the stock firmware
- Run the stock firmware as briefly as possible

**The good news:** Installing our Android 16 build **completely eliminates**
any pre-installed malware — we build from clean AOSP source and replace the
entire system partition.

See [docs/SECURITY.md](docs/SECURITY.md) for full details and detection commands.

---
## Disclaimer

This is an unofficial community project. It is not affiliated with or endorsed by:
- Rockchip Semiconductor
- The X88 Pro manufacturer
- Google / Android Open Source Project

Flashing custom firmware may void your warranty. The authors are not responsible
for bricked devices. Always keep your Phase 1 backup!
