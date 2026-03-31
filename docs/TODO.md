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

### HIGH: Install rkdeveloptool on build machine — Phase 5 blocker
- **Status:** NOT installed (`which rkdeveloptool` returns nothing)
- **Required for:** All `phase5_flash.sh` commands that write to device partitions
- **How:**
  ```bash
  sudo apt-get install libusb-1.0-0-dev
  git clone https://github.com/rockchip-linux/rkdeveloptool
  cd rkdeveloptool && autoreconf -i && ./configure && make && sudo make install
  ```
- Must be done before attempting any flash step

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

## Rebuild scope after Phase 4

No full rebuild needed for any of the remaining tasks:

| Task | What to rebuild | Command | Time |
|---|---|---|---|
| ~~FORTIFY_SOURCE patch~~ ✅ | ~~Kernel + boot.img~~ | — done — | — |
| ~~Pre-flash sweep (Issues 27-29)~~ ✅ | ~~vendor.img + super.img~~ | — done — | — |
| SELinux enforcing | boot.img only (cmdline) + vendor per denial | `m bootimage`, then `m vendorimage` per fix | Minutes per iteration |
| CVE audit | Nothing — docs only | — | — |
