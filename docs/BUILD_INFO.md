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

## Phase 5 Rebuild — 2026-04-01 (boot header v2 fix)

First flash attempt (2026-03-31) failed because the stock Android 11 uboot on the
X88 Pro only accepts boot image header v2; AOSP 16 defaults to v4. Six additional
issues were found and resolved during the rebuild (Issues 33–38).

**BoardConfig.mk changes from Phase 4 baseline:**

| Change | Reason |
|---|---|
| `BOARD_BOOT_HEADER_VERSION := 2` | Stock A11 uboot cannot parse v4 header |
| `BOARD_MKBOOTIMG_ARGS += --dtb ... --dtb_offset ...` | v2 header requires embedded DTB |
| `BUILD_BROKEN_DUP_RULES := true` | BT .rc regeneration duplicate (Issue 35) |
| `AB_OTA_UPDATER := false` | Default `true` caused check_partition_sizes to halve super budget |
| Removed `system_ext` from partition list | Empty image path caused Python crash |
| Added `BOARD_AVB_RECOVERY_*` variables | Required for non-A/B + AVB (Issue 38) |

**Rebuilt images (2026-04-01):**

| Image | Size | Built | Notes |
|---|---|---|---|
| `boot.img` | 64 MB | 00:12 | **v2 header + embedded DTB** — compatible with stock A11 uboot |
| `system.img` | 1.1 GB | 09:48 | Rebuilt |
| `vendor.img` | 97 MB | 09:48 | Rebuilt |
| `product.img` | 284 MB | 09:48 | Rebuilt |
| `odm.img` | 890 KB | 09:48 | Rebuilt |
| `recovery.img` | 96 MB | 09:48 | Rebuilt with recovery AVB key |
| `vbmeta.img` | 64 KB | 09:48 | Updated — includes recovery AVB footer |
| `super.img` | 1.5 GB | 10:04 | Rebuilt (single-slot, no system_ext) |
| `dtbo.img` | 157 KB | 00:12 | Unchanged |

**Total build issues resolved: 38** (see BUILD_TROUBLESHOOTING.md issues 33–38)

## Critical Testing Rounds — 2026-03-31

Three successive rounds of critical review were done before committing to Phase 5.
Each round found issues that would have caused silent first-boot failures.
Full details for each issue are in `BUILD_TROUBLESHOOTING.md`.

---

### Round 1 — Pre-build validation (Issues 24–26)

Triggered after the main Phase 4 build produced images. Goal: audit what the build
produced before running any pre-flash tooling.

| Issue | Problem | First-boot impact |
|---|---|---|
| 24 | `bcmdhd.ko` extracted from stock Android 11 had `vermagic: 4.19.172` — BSP kernel is `5.10.226` | Linux refuses modules with mismatched `vermagic` — WiFi dead |
| 25 | `PRODUCT_SYMLINKS` is not a real build variable — silently ignored | Generic firmware names (`fw_bcmdhd.bin`, `nvram.txt`) never installed — driver loads, can't find firmware |
| 26 | BT HAL binary only referenced in dead `device.mk` (never included by the build) | Binary never installed to `/vendor/bin/hw/` — BT HAL never starts |

**Fixes:**
- Rebuilt `bcmdhd.ko` from BSP 5.10 kernel source (required two `-Werror=address` patches in `wl_android.c`)
- Replaced `PRODUCT_SYMLINKS` with duplicate `PRODUCT_COPY_FILES` entries using generic destination names
- Added BT binary to `Android.bp` as `cc_prebuilt_binary` + `PRODUCT_PACKAGES`

---

### Round 2 — "Strictest" pre-flash sweep (Issues 27–31)

Full adversarial audit: assume everything that could be wrong is wrong.
Found 5 issues requiring a `vendor.img` rebuild.

| Issue | Problem | First-boot impact |
|---|---|---|
| 27 | `dhd_static_buf.ko` not in vendor — `modinfo bcmdhd.ko` lists `depends: dhd_static_buf` | `bcmdhd.ko` fails to load — WiFi dead |
| 28 | `libdrm.so` only in dead `device.mk` — never installed to vendor | gralloc allocator HAL `dlopen` fails — no graphics |
| 29 | SELinux `file_contexts` had `/vendor/lib/modules/bcmdhd.ko` — install path is `/vendor/etc/modules/` | SELinux label on a non-existent path |
| 30 | 7 HAL service `.rc` files never installed — `cc_prebuilt_binary` has no `init_rc:` support unlike source-built binaries | keymaster, gatekeeper, DRM, power, lights, BT, neural-networks HALs never start |
| 31 | `dhd_static_buf.ko` installed to vendor but nothing loads it — `wifi_load_driver()` uses `finit_module(2)` directly, no kernel module dependency resolution | `bcmdhd.ko` insmod returns `Unknown symbol in module` |

**Key technical insight (Issue 31):** Android's `wifi_load_driver()` in
`libwifi_hal/wifi_hal_common.cpp` calls `finit_module(2)` directly — not `modprobe`.
The kernel does not resolve module dependencies with `finit_module`. If `dhd_static_buf.ko`
is not already loaded, `bcmdhd.ko` fails immediately.

**Fixes:**
- Copied `dhd_static_buf.ko` from BSP kernel build output into `proprietary/modules/`, added to `Android.bp` + `PRODUCT_PACKAGES`
- Fixed SELinux `file_contexts` paths to `/vendor/etc/modules/`
- Added 7 init.rc files via `PRODUCT_COPY_FILES` in `aosp_x88pro.mk`
- Created `init.bcmdhd.rc` with `on boot insmod /vendor/etc/modules/dhd_static_buf.ko`

---

### Round 3 — Documentation audit + dead code cleanup (Issue 32)

Goal: verify docs and scripts match the actual build state. No rebuild needed.

| Item | Problem | Fix |
|---|---|---|
| Issue 32 | BT init.rc in `PRODUCT_COPY_FILES` duplicated what AOSP's Soong module already installs → ckati "overriding commands" build failure | Removed our entry — AOSP module owns that `.rc` |
| libdrm dead code | `cc_prebuilt_library_shared { name: "libdrm" }` added in Round 2, but `external/libdrm` has `vendor_available: true` — Soong drops the prebuilt silently and uses the AOSP copy | Removed vendor prebuilt from `Android.bp`; libdrm moved to Category 1 in inventory; counts corrected to 16/36/5/2 = 59 |
| Makefile | Phase 4 and 5 had no status markers | Added `[✅ COMPLETE]` and `[🔜 READY — install rkdeveloptool first]` |
| TODO.md | Three Phase 5 blockers undocumented | Added: `rkdeveloptool` not installed (hard blocker), `tee-supplicant` absent (acceptable for bring-up), camera blobs not wired up |
| Issue count | `BUILD_INFO.md` showed 31 issues | Updated to 32 |

---

## Known Build Deviations from Upstream

| Item | Status | Notes |
|---|---|---|
| `CONFIG_FORTIFY_SOURCE` | ✅ Enabled | Mali CSF driver patched (Issue 22) |
| SELinux | ⚠️ Permissive | For bring-up, switch to enforcing later |
| AVB | ✅ Enabled | `BOARD_AVB_ENABLE := true`; vbmeta flags=3 (eng build, verification disabled) |
| Widevine | ⚠️ L3 only | No L1 secure video path |
| Boot header | ⚠️ v2 (not v4) | Temporary — stock A11 uboot requires v2; migrate to v4 after uboot upgrade |
| A/B OTA | ⚠️ Disabled | `AB_OTA_UPDATER := false` — X88 Pro is single-slot |

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
