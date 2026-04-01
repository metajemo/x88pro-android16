# Project TODO List

## Security TODOs (Phase 4+)

### ~~HIGH: Re-enable CONFIG_FORTIFY_SOURCE in kernel~~ ✅ DONE
- **Commit:** `e4d2951` (2026-03-31)
- **Fix:** Patched `mali_kbase_csf_firmware.c` — declared linker boundary symbols
  as `extern char mali_csffw[]` (incomplete array) instead of `extern char mali_csffw`
  (single byte). FORTIFY_SOURCE now enabled and kernel builds clean.
- **Documented:** Issue 22 in `docs/BUILD_TROUBLESHOOTING.md`

### MEDIUM: Switch SELinux from permissive to enforcing
- **File:** `device/rockchip/x88pro/BoardConfig.mk`
- **When:** After initial boot is confirmed working
- **How:** Remove `androidboot.selinux=permissive` from BOARD_KERNEL_CMDLINE
  Then fix all SELinux denials via `adb shell dmesg | grep avc`

### MEDIUM: Re-enable Widevine L1 investigation
- Currently L3 only (no secure video path)
- May be possible with proper OP-TEE configuration

### LOW: Audit vendor blobs for security issues
- Blobs from 2022 Android 11 firmware
- Particularly: libwvdrmengine.so, libbt-vendor.so, bcmdhd.ko

## Phase 4 TODOs

### Build kernel with RKNPU enabled
- ~~Verify CONFIG_RKNPU=y builds correctly~~ ✅ Done — kernel built successfully with RKNPU enabled
- Test rknn_server connectivity (after first boot)

### SELinux policy for custom services
- rknn_server: u:r:rknn_server:s0
- bcmdhd: WiFi socket access
- rockchip.hardware.outputmanager

## Documentation TODOs

### ~~Document partition layout changes (Android 11 → Android 16)~~ ✅ DONE
- **File:** `docs/PARTITION_LAYOUT.md` — created 2026-03-31
- Includes physical partition table, dynamic partition comparison (A11 vs A16), flash target list

## Phase 5 TODOs (Pre-Flash Blockers)

### ~~HIGH: Install rkdeveloptool on build machine~~ ✅ DONE
- **Status:** Installed at `/usr/bin/rkdeveloptool` (ver 1.0.0)
- **simg2img** also confirmed at `/usr/bin/simg2img`

### LOW: tee-supplicant binary absent — keymaster TEE ops will fail on first boot
- `tee-supplicant` is not in the stock vendor dump and was not extracted
- `android.hardware.keymaster@4.0-service.optee` will fail TEE operations
- **Impact:** Acceptable for a fresh device with no PIN/password set (no keystore
  data to protect). Screen lock and KeyStore will degrade gracefully.
- **Action:** None required for bring-up. Investigate if OP-TEE is needed later.

### LOW: Camera binaries not in PRODUCT_PACKAGES — camera will not work on first boot
- `proprietary/bin/` contains camera-related binaries that were extracted from stock
- None are declared in `Android.bp` or `PRODUCT_PACKAGES`
- **Impact:** Camera app will crash or show no preview
- **Action:** Inventory camera blobs, add to Android.bp + PRODUCT_PACKAGES after
  confirming which camera HAL version the stock firmware uses

### ~~dtbo.img — use stock or build from BSP~~ ✅ DONE
- **Commit:** `c7fcdac` — rebuilt from BSP kernel `rk3566-box-demo-v10.dtb` via `mkdtimg`
- **Location:** `device/rockchip/x88pro/prebuilt/dtbo.img` (157 KB)
- **Config:** `BOARD_PREBUILT_DTBOIMAGE := device/rockchip/x88pro/prebuilt/dtbo.img`

### Flash script
- ~~Write phase5_flash.sh~~ ✅ Done
- Test partition-by-partition flashing
- Test full restore from Phase 1 backup

### ~~Update vendor blob inventory~~ ✅ DONE
- **Updated 2026-03-31** after pre-flash sweep found Issues 27-29
- Moved `libdrm` and BT service binary from Category 1 (AOSP) → Category 2 (vendor prebuilt)
- Added `dhd_static_buf.ko` to Category 4 (BSP kernel built)
- Updated summary: 15 AOSP / 37 stock / 5 SDK / 2 BSP = 59 total

## Phase 5 TODOs (Post-Flash)

### HIGH: Restore working SPL / recover device from flash incident
- **Status:** Device boots to no output (HDMI, ADB, USB) — SPL at LBA 0x40 is the rkbin
  generic SPL (920 MHz variant last written), which may not match X88 Pro DDR timing
- **Device is NOT bricked:** BootROM + pinhole button always gives MaskROM access
- **Blocker:** Without UART we cannot see whether DDR init passes or fails
- **Options:**
  1. **UART** (FT232RL, 1500000 baud) — ordered, will show exact failure point
  2. **Stock firmware preloader** — find an X88 Pro stock firmware package online;
     it will contain the correct board-specific preloader for LBA 0x40
  3. **Try remaining DDR frequency variants** from rkbin (780 MHz, 528 MHz ultra)
- **GPT partition offsets confirmed** (see Issue 39 in BUILD_TROUBLESHOOTING.md):
  - SPL (no GPT): LBA 0x40
  - uboot: LBA 0x4000
  - trust: LBA 0x6000
  - boot: LBA 0xC800
  - super: LBA 0x1EF200
- **Current eMMC state:**
  - LBA 0x40: rkbin generic SPL 920 MHz (may be incompatible)
  - LBA 0x4000: backup/uboot.img ✓
  - LBA 0x6000: backup/trust.img ✓
  - LBA 0xC800: backup/boot.img (A11) ✓
  - super: A16 content (not the blocker)

### MEDIUM: Migrate boot image to header version 4
- **Current state:** Boot image uses header v2 (required for stock A11 uboot compatibility)
- **Why v4 matters:** GKI standard; future Android updates will assume v4; v2 is legacy
- **Prerequisite:** Replace stock A11 uboot with a Rockchip Android 12/13 compatible uboot
  that can parse v4 headers (e.g., from a Rockchip Android 12 BSP for RK3566)
- **Steps when ready:**
  1. Flash a compatible Rockchip RK3566 uboot (via rkdeveloptool `write-partition uboot`)
  2. Remove `BOARD_BOOT_HEADER_VERSION := 2` and the `--dtb` mkbootimg args from BoardConfig.mk
  3. Rebuild `boot.img` with `m bootimage`
  4. Flash and verify
- **Risk:** Wrong uboot = brick (keep Phase 1 uboot.img backup safe)

## Rebuild scope after Phase 5

| Task | What to rebuild | Command | Time |
|---|---|---|---|
| ~~FORTIFY_SOURCE patch~~ ✅ | ~~Kernel + boot.img~~ | — done — | — |
| ~~Pre-flash sweep (Issues 27-29)~~ ✅ | ~~vendor.img + super.img~~ | — done — | — |
| ~~Boot header v2 fix~~ ✅ | ~~boot.img + super.img~~ | — done — | — |
| SELinux enforcing | boot.img only (cmdline) + vendor per denial | `m bootimage`, then `m vendorimage` per fix | Minutes per iteration |
| Boot header v4 | boot.img only (after uboot upgrade) | `m bootimage` | Minutes |
| CVE audit | Nothing — docs only | — | — |
