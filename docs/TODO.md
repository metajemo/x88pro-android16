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
- Verify CONFIG_RKNPU=y builds correctly
- Test rknn_server connectivity

### SELinux policy for custom services
- rknn_server: u:r:rknn_server:s0
- bcmdhd: WiFi socket access
- rockchip.hardware.outputmanager

## Phase 5 TODOs

### Flash script
- Write phase5_flash.sh
- Test partition-by-partition flashing
- Test full restore from Phase 1 backup
