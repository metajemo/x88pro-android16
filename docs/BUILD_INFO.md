# Build Information — X88 Pro Android 16

## Build Environment

| Component | Version | Notes |
|---|---|---|
| AOSP Branch | `android-16.0.0_r1` | Stable release |
| Build ID | `BP2A.250605.031.A2` | |
| Security patch level | `2025-07-01` | |
| Java | OpenJDK 17.0.18 | Must be 17, not 21 |
| Clang | 20.0.0 (r547379) | Latest Android prebuilt (Feb 2025), +PGO +Bolt +LTO +MLGO. Newer than upstream LLVM numbering suggests — do not upgrade. |
| BSP Kernel | 5.10.x | `rockchip-linux/kernel develop-5.10` |
| Kernel defconfig | `rockchip_defconfig` | + `kernel-config-x88pro.config` overlay |
| Build machine | Ubuntu 24.04.4 | 12 cores, 32GB RAM, NVMe |
| ccache | 4.9.1 | 50GB cache |

## Clang Build Features

The Android prebuilt Clang 20.0.0 includes:
- **PGO** (Profile Guided Optimization) — better runtime performance
- **Bolt** — binary optimization and layout tool
- **LTO** (Link Time Optimization) — cross-module optimization
- **MLGO** (Machine Learning Guided Optimization) — ML-based inlining

These are all enabled by default in the AOSP build system for release builds.

## Kernel Build

| Component | Version |
|---|---|
| Kernel source | Rockchip BSP 5.10 |
| Cross compiler | `aarch64-linux-gnu-gcc` (GCC 13.3.0) |
| Base defconfig | `rockchip_defconfig` (1050 entries) |
| Overlay | `kernel-config-x88pro.config` |
| Kernel Image | 36MB (arch/arm64/boot/Image) |
| Build time | ~9 minutes (12 cores) |

## Known Build Deviations from Upstream

| Item | Status | Notes |
|---|---|---|
| `CONFIG_FORTIFY_SOURCE` | ❌ Disabled | BSP Mali driver bug, see TODO.md |
| SELinux | ⚠️ Permissive | For bring-up, switch to enforcing later |
| AVB | ✅ Enabled | `BOARD_AVB_ENABLE := true` |
| Widevine | ⚠️ L3 only | No L1 secure video path |

## Vendor Blob Sources

See [VENDOR_BLOB_INVENTORY.md](VENDOR_BLOB_INVENTORY.md) for full details.

| Source | Count | Examples |
|---|---|---|
| AOSP built from source | 18+ | ClearKey, audio HALs, health HAL |
| Stock Android 11 vendor | 34 | Mali GPU, MPP video, WiFi/BT |
| Rockchip RKNN2 SDK | 5 | NPU runtime, rknn_server |
| BSP kernel built | 1 | bcmdhd.ko WiFi module |
