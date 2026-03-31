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

## Phase 4 Build Output — 2026-03-31

| Image | Size | Notes |
|---|---|---|
| `boot.img` | 64 MB | Kernel + ramdisk |
| `super.img` | 1.5 GB | Combined dynamic partitions |
| `system.img` | 1.2 GB | (inside super) |
| `vendor.img` | 94 MB | (inside super) |
| `product.img` | 284 MB | (inside super) |
| `odm.img` | 889 KB | (inside super) |
| `vbmeta.img` | 64 KB | AVB metadata |
| `recovery.img` | 96 MB | Recovery partition |
| `dtbo.img` | 157 KB | Built from BSP kernel `rk3566-box-demo-v10.dtb` via mkdtimg |

**Build time:** ~10 minutes (incremental, 12 cores, -j4)
**Total build issues resolved:** 32 (see BUILD_TROUBLESHOOTING.md)

## Known Build Deviations from Upstream

| Item | Status | Notes |
|---|---|---|
| `CONFIG_FORTIFY_SOURCE` | ✅ Enabled | Mali CSF driver patched (Issue 22) |
| SELinux | ⚠️ Permissive | For bring-up, switch to enforcing later |
| AVB | ✅ Enabled | `BOARD_AVB_ENABLE := true` |
| Widevine | ⚠️ L3 only | No L1 secure video path |

## Vendor Blob Sources

See [VENDOR_BLOB_INVENTORY.md](VENDOR_BLOB_INVENTORY.md) for full details.

| Source | Count | Examples |
|---|---|---|
| AOSP built from source | 16 | ClearKey, audio HALs, health HAL, libdrm (vendor_available) |
| Stock Android 11 vendor | 36 | Mali GPU, MPP video, WiFi/BT |
| Rockchip RKNN2 SDK | 5 | NPU runtime, rknn_server |
| BSP kernel built | 2 | bcmdhd.ko + dhd_static_buf.ko |

## Pre-Flash Validation — 2026-03-31

All images validated before flashing. One critical bug was found and fixed (Issue 23).

### Image validation

| Test | Tool | Result |
|---|---|---|
| Image formats | `file` | boot.img, recovery.img: valid Android boot format ✓ |
| Partition size vs limits | manual | All images fit within their partition limits (super: 1.5 GB of 3.1 GB used) ✓ |
| Dynamic partition layout | `lpdump` | system_a / vendor_a / product_a / odm_a all present with correct extents ✓ |
| Boot image contents | `unpack_bootimg` | Kernel 5.10.226, OS 16.0.0, patch 2025-06 ✓ |
| DTBO image | `mkdtimg dump` | 1 entry, compatible=`rockchip,rk3566-box-demo-v10` ✓ |
| AVB metadata | `avbtool` | vbmeta flags=3 (verification disabled — expected for eng build) ✓ |
| VINTF compatibility | `checkvintf` | Manifest + compatibility_matrix read successfully ✓ |

### Kernel config verification

| Config | Expected | Actual |
|---|---|---|
| `CONFIG_FORTIFY_SOURCE` | y | ✅ y |
| `CONFIG_STACKPROTECTOR_STRONG` | y | ✅ y |
| `CONFIG_STRICT_KERNEL_RWX` | y | ✅ y |
| `CONFIG_BCMDHD` | y | ✅ y |
| `CONFIG_MALI_BIFROST` | y | ✅ y |
| `CONFIG_ROCKCHIP_RKNPU` | y | ✅ y |
| `CONFIG_ROCKCHIP_MPP_SERVICE` | y | ✅ y |
| `CONFIG_ROCKCHIP_MPP_RKVDEC2` | y | ✅ y |

### Vendor image contents

| Component | File | Status |
|---|---|---|
| Mali GPU driver | `lib64/egl/libGLES_mali.so` | ✅ Present |
| Mali gralloc HAL | `lib64/hw/android.hardware.graphics.allocator@4.0-impl-bifrost.so` | ✅ Present |
| Vulkan | `lib64/hw/vulkan.rk356x.so` | ✅ Present |
| HWComposer | `lib64/hw/hwcomposer.rk30board.so` | ✅ Present |
| Video decode | `lib64/libmpp.so` | ✅ Present |
| NPU runtime | `lib64/librknnrt.so` | ✅ Present |
| NPU server | `bin/rknn_server` | ✅ Present |
| WiFi firmware | `etc/firmware/fw_bcm4359c0_ag*.bin` | ✅ Present |
| BT firmware | `etc/firmware/BCM4359C0.hcd` | ✅ Present |
| WiFi driver | `etc/modules/bcmdhd.ko` | ✅ Present |
| WiFi driver dependency | `etc/modules/dhd_static_buf.ko` | ✅ Present (added Issue 27) |
| DRM library | `lib64/libdrm.so` | ✅ Present (added Issue 28) |

### Bugs found and fixed

**Issue 23 — bcmdhd.ko path mismatch (would have broken WiFi on first boot)**

`prebuilt_etc` in `Android.bp` installs `bcmdhd.ko` to `/vendor/etc/modules/` but
`WIFI_DRIVER_MODULE_PATH` in `BoardConfig.mk` pointed to `/vendor/lib/modules/`.
The WiFi HAL would have called `insmod` on a path that does not exist.

Fixed by updating `WIFI_DRIVER_MODULE_PATH` in `BoardConfig.mk` to match the actual
install path. See Issue 23 in `BUILD_TROUBLESHOOTING.md` for full details.

**Issue 27 — dhd_static_buf.ko missing (would have broken WiFi module load)**

`modinfo bcmdhd.ko` lists `depends: dhd_static_buf`. The dependency module was built
alongside bcmdhd but never added to `Android.bp` or installed to vendor. Fixed by
copying into `proprietary/modules/` and declaring in `Android.bp` + `PRODUCT_PACKAGES`.

**Issue 28 — libdrm.so missing (would have crashed graphics allocator HAL)**

`libdrm.so` existed in `proprietary/lib64/` but was only referenced in the dead
`device.mk`. Not in `Android.bp`, not in vendor. Fixed by adding to both.

**Issue 29 — SELinux file_contexts wrong bcmdhd path**

`/vendor/lib/modules/bcmdhd.ko` in `file_contexts` — correct path is
`/vendor/etc/modules/`. Also added label for `dhd_static_buf.ko`.
