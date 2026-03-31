# Project TODO List

## Security TODOs (Phase 4+)

### HIGH: Re-enable CONFIG_FORTIFY_SOURCE in kernel
- **File:** `device/rockchip/x88pro/kernel-config-x88pro.config`
- **Why disabled:** BSP Mali Bifrost driver (`mali_kbase_csf_firmware.o`)
  has a string read that trips FORTIFY_SOURCE buffer overflow detection
- **Fix needed:** Either patch the Mali driver or upgrade BSP kernel
- **How to re-enable:** Change in kernel-config-x88pro.config:
  `# CONFIG_FORTIFY_SOURCE is not set` → `CONFIG_FORTIFY_SOURCE=y`
  Then verify kernel builds clean

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

### Document partition layout changes (Android 11 → Android 16)
- **File:** `docs/PARTITION_LAYOUT.md` (create if not exists)
- **What:** Side-by-side comparison of stock Android 11 partition layout vs the new Android 16 layout
- **Include:** partition names, sizes, filesystem types, and what changed (resized, added, removed)
- **Source for Android 11:** Phase 1 backup partition dump / `rkdeveloptool pl` output from original device
- **Source for Android 16:** `BoardConfig.mk` partition size definitions + `lpdump` on built super.img

## Phase 5 TODOs

### dtbo.img — use stock or build from BSP
- Currently using `backup/dtbo.img` (stock Android 11) for flashing
- **Option A (simple):** Copy `backup/dtbo.img` to device tree as prebuilt:
  `BOARD_PREBUILT_DTBOIMAGE := device/rockchip/x88pro/prebuilt/dtbo.img`
- **Option B (correct):** Configure BSP kernel to produce dtbo.img via
  `BOARD_KERNEL_SEPARATED_DTBO := true` and kernel DTB overlay config
- For initial bring-up, stock dtbo is fine — only needed if kernel DT changes

### Flash script
- ~~Write phase5_flash.sh~~ ✅ Done
- Test partition-by-partition flashing
- Test full restore from Phase 1 backup

### Update vendor blob inventory
- Cross-check `docs/VENDOR_BLOB_INVENTORY.md` against the final build output
- Verify no blobs were added/removed during iterative conflict resolution
- Update any entries that changed (source, version, notes)
- Confirm Category 1 (AOSP built) list matches actual removed conflicts

## Rebuild scope after Phase 4

No full rebuild needed for any of the remaining tasks:

| Task | What to rebuild | Command | Time |
|---|---|---|---|
| FORTIFY_SOURCE patch | Kernel + boot.img | `make -j12` in kernel dir, then `m bootimage` | ~9 min + few min |
| SELinux enforcing | boot.img only (cmdline) + vendor per denial | `m bootimage`, then `m vendorimage` per fix | Minutes per iteration |
| CVE audit | Nothing — docs only | — | — |
| Vendor blob inventory | Nothing — docs only | — | — |

A full rebuild would only be needed if the audit revealed a blob that shouldn't be in the build at all — an unlikely edge case.
