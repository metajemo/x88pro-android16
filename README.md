# Android 16 for X88 Pro (RK3566)

Community project to build and run Android 16 on the **X88 Pro** Android TV box powered by the **Rockchip RK3566** SoC.

> ⚠️ **Work in progress** — This project is actively being developed. Follow along or contribute!

---

## Device Specifications

| Component | Details |
|---|---|
| **Board** | X88PRO-RK3566-4D32-V1.0 |
| **SoC** | Rockchip RK3566 (4x ARM Cortex-A55 @ 1.8GHz) |
| **GPU** | ARM Mali-G52 |
| **RAM** | 8GB LPDDR4 |
| **Storage** | 128GB eMMC |
| **Ethernet** | Gigabit (RTL8211) |
| **WiFi/BT** | Onboard combo module |
| **Video out** | HDMI 2.0 |
| **USB** | 3x USB-A + 1x USB-C (OTG) |
| **Stock OS** | Android 11 (kernel 4.19.172) |

---

## Project Status

| Phase | Description | Status |
|---|---|---|
| Phase 1 | Device extraction & backup | ✅ Complete |
| Phase 2 | Build environment setup | ✅ Complete |
| Phase 3 | Device tree & vendor blobs | 🚧 In progress |
| Phase 4 | Android 16 build | ⏳ Pending |
| Phase 5 | Flash & verify | ⏳ Pending |

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
git clone https://github.com/YOUR_USERNAME/x88pro-android16.git
cd x88pro-android16

# Run extraction (replace IP with your box's IP address)
make phase1 BOX_IP=192.168.1.105

# Or run the script directly
chmod +x scripts/phase1_extraction.sh
./scripts/phase1_extraction.sh 192.168.1.105
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
make phase2

# Or step by step:
make phase2-deps    # Install Ubuntu packages
make phase2-repo    # Install repo tool
make phase2-sync    # Sync AOSP (~100GB, takes hours)
```

---

### Phase 3 — Prepare device tree and vendor blobs

```bash
make phase3
```

This will:
- Convert the binary device tree blob (DTB) back to human-readable DTS source
- Extract proprietary vendor blobs from super.img (GPU, VPU, WiFi drivers)
- Generate a proper Android 16 device tree for the X88 Pro

---

### Phase 4 — Build Android 16

```bash
# Full build (takes several hours)
make phase4

# Or build components separately:
make phase4-setup   # Configure lunch target
make phase4-kernel  # Build kernel (~30-60 min)
make phase4-aosp    # Build AOSP (~3-8 hours depending on hardware)
```

---

### Phase 5 — Flash to device

```bash
make phase5 BOX_IP=192.168.1.105
```

> ⚠️ **Warning:** This replaces Android 11 with Android 16. Make sure Phase 1
> backup exists before flashing!

---

## Restoring Original Android 11

If anything goes wrong, you can restore the original firmware using the Phase 1 backup:

```bash
# TODO: restore script (phase5_restore.sh) - coming soon
```

---

## How to Enable ADB on the X88 Pro

1. Go to **Settings → About Device**
2. Tap **Build Number** 7 times to enable Developer Options
3. Go to **Settings → Developer Options**
4. Enable **USB Debugging**
5. Enable **ADB over Network** (or "Wireless Debugging")
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
│   ├── phase4_build.sh             # AOSP build script
│   └── phase5_flash.sh             # Flashing script
├── device/
│   └── rockchip/
│       └── x88pro/
│           ├── device.mk           # Device configuration
│           ├── BoardConfig.mk      # Board-level build config
│           ├── AndroidProducts.mk  # Product definition
│           └── proprietary/        # Vendor blobs (not in git)
├── kernel/
│   └── configs/                    # Kernel config fragments
└── docs/
    ├── HARDWARE.md                 # Detailed hardware documentation
    ├── PARTITIONS.md               # Partition layout reference
    └── TROUBLESHOOTING.md          # Common issues and fixes
```

---

## Contributing

This is a community project and contributions are very welcome!

**Ways to help:**
- Test builds and report issues
- Improve device tree entries
- Write documentation
- Help identify vendor blobs
- Port drivers from other RK3566 projects (Radxa Rock 3, Pine64 Quartz64)

**Related projects that helped:**
- [Rockchip Linux](https://github.com/rockchip-linux) — Official Rockchip kernel and manifests
- [Radxa Rock 3](https://github.com/radxa) — Another RK3566 board with good community support
- [LibreELEC RK356x](https://github.com/LibreELEC/LibreELEC.tv) — Linux for RK356x boxes

---

## License

Build scripts and device configuration files in this repository are released under the **Apache License 2.0**.

Android Open Source Project (AOSP) components are subject to their own licenses.
Proprietary vendor blobs extracted from the device are owned by Rockchip and their respective vendors — they are **not** included in this repository and must be extracted from your own device using the Phase 1 script.

---

## Disclaimer

This is an unofficial community project. It is not affiliated with or endorsed by:
- Rockchip Semiconductor
- The X88 Pro manufacturer
- Google / Android Open Source Project

Flashing custom firmware may void your warranty. The authors are not responsible for bricked devices. Always keep your Phase 1 backup!
