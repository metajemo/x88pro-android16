# Security Hardening Guide — X88 Pro Android 16 Build

## Overview

This document covers known vulnerabilities in our build components and
concrete steps to mitigate them before and during the Phase 4 build.

---

## 1. AOSP Security Patch Level

Our base: `android-16.0.0_r1` — security patch level **2025-07-01**

This means patches up to July 2025 are included. Known vulnerabilities
patched AFTER this date that affect our build:

| CVE | Severity | Component | Patch Level | Impact |
|---|---|---|---|---|
| CVE-2025-48633 | High | Framework | 2025-12-01 | Info disclosure, exploited in wild |
| CVE-2025-48572 | High | Framework | 2025-12-01 | Privilege escalation, exploited in wild |
| CVE-2025-48631 | Critical | Framework | 2025-12-01 | Remote DoS |
| CVE-2026-21385 | Unknown | Framework | 2026-03-01 | Limited exploitation reported |

**Mitigation:** Our build is a community project — not commercially deployed.
For production use, cherry-pick the relevant patches from AOSP master.
For personal use, the risk is low — these require local app execution.

**Action for Phase 4:**
```bash
# Check if our AOSP branch has any pending security backports
cd aosp
git log --oneline android-16.0.0_r1..origin/android16-security-release \
    2>/dev/null | head -20 || echo "No separate security branch found"
```

---

## 2. BSP Kernel 5.10 Security

The Rockchip BSP kernel (5.10) is a vendor fork that may lag behind
upstream LTS security patches.

**Known exploited kernel CVEs affecting kernel 5.10:**

| CVE | Component | Severity | CISA KEV | Notes |
|---|---|---|---|---|
| CVE-2024-53150 | ALSA USB audio | Medium | ✅ Yes | Out-of-bounds read via malicious USB device |
| CVE-2024-53197 | ALSA USB audio | High | ✅ Yes | Memory corruption via malicious USB device |
| CVE-2024-50302 | HID core | Medium | ✅ Yes | Kernel memory leak via malicious HID device |
| CVE-2025-21756 | vsock | High | ✅ Yes | Privilege escalation |

**Mitigations we can apply in kernel config:**
```
# Disable unused attack surface in kernel-config-x88pro.config
# CONFIG_USB_AUDIO is not set          <- reduces USB audio attack surface
# CONFIG_BT_HIDP is not set            <- no BT HID needed for TV box
CONFIG_SECURITY_DMESG_RESTRICT=y       <- restrict dmesg to root
CONFIG_RANDOMIZE_BASE=y                 <- KASLR (likely already set)
CONFIG_STACKPROTECTOR_STRONG=y          <- stack canaries
CONFIG_FORTIFY_SOURCE=y                 <- buffer overflow detection
CONFIG_STRICT_KERNEL_RWX=y             <- prevent kernel code modification
CONFIG_DEBUG_CREDENTIALS=n             <- disable in production
```

---

## 3. bcmdhd WiFi Driver Security

The bcmdhd out-of-tree driver has a history of security vulnerabilities:

| CVE | Year | Type | Notes |
|---|---|---|---|
| CVE-2017-13213 | 2017 | Privilege escalation | bcmdhd elevation of privilege |
| Broadpwn | 2017 | Remote code execution | BCM4359 specifically affected |
| CVE-2017-0561 | 2017 | Heap overflow | TDLS implementation |

The BCM4359c0 chip was specifically mentioned in the Broadpwn research.
However, these are old vulnerabilities and modern bcmdhd versions have
patches for them.

**Mitigations:**
- Build bcmdhd from the BSP kernel source (not the prebuilt .ko)
- Enable `CONFIG_CFG80211=y` for more secure WiFi management
- Use WPA3 where possible
- SELinux policy to restrict bcmdhd socket access

---

## 4. Build Hardening Flags

Add these to `BoardConfig.mk` before building:
```makefile
# Enable full RELRO (Relocation Read-Only)
BOARD_GLOBAL_CFLAGS += -fstack-protector-strong
BOARD_GLOBAL_CFLAGS += -D_FORTIFY_SOURCE=2
BOARD_GLOBAL_CFLAGS += -Wformat -Wformat-security

# PIE (Position Independent Executables) - enabled by default in Android 16
# but verify:
TARGET_PIE_ENABLE := true

# SELinux enforcing mode (not permissive)
BOARD_SEPOLICY_DIRS += device/rockchip/x88pro/sepolicy
# Note: start permissive for bring-up, then switch to enforcing

# Verified Boot
BOARD_AVB_ENABLE := true
```

---

## 5. SELinux Policy Recommendations

Our initial build uses `permissive` SELinux for bring-up. Before declaring
the build stable:

1. Boot with `enforcing` mode
2. Check `adb shell dmesg | grep avc` for denials
3. Use `audit2allow` to generate minimal policy rules
4. Never use `permissive` in production

Critical services that need SELinux policies:
- `rknn_server` (NPU daemon) — u:r:rknn_server:s0
- `bcmdhd` (WiFi module) — needs socket access
- `rockchip.hardware.outputmanager` — display access

---

## 6. Vendor Blob Trust Assessment

Our vendor blobs came from the stock Android 11 firmware (2022).
Scan results: **clean** (no BADBOX indicators found).

However these blobs are:
- **Unaudited** — we cannot inspect closed-source binary blobs
- **Old** — from 2022, may contain unpatched vulnerabilities
- **Proprietary** — ARM, Broadcom, Rockchip own these

**Acceptable risk:** For a community TV box project this is standard
practice (same approach as LineageOS, GrapheneOS device ports).

**Higher risk blobs:**
- `libwvdrmengine.so` — Widevine DRM (internet-facing, processes media)
- `libbt-vendor.so` — Bluetooth stack (wireless, processes packets)
- `bcmdhd.ko` — WiFi driver (internet-facing, processes packets)

---

## 7. Network Security Recommendations

For users running our Android 16 build:

- **Use a guest VLAN** for the TV box — isolate from other devices
- **Disable ADB over network** when not actively developing:
  `adb shell settings put global adb_enabled 0`
- **No sensitive accounts** — treat as a media-only device
- **Monitor traffic** — consider Pi-hole or similar for DNS monitoring

---

## 8. Pre-Build Security Checklist

Before starting Phase 4 build:

- [ ] Verify AOSP `android-16.0.0_r1` tag is authentic:
  `cd aosp && git verify-tag android-16.0.0_r1`
- [ ] Add kernel hardening configs to `kernel-config-x88pro.config`
- [ ] Set `BOARD_AVB_ENABLE := true` in BoardConfig.mk
- [ ] Plan SELinux policy for custom services (rknn_server, bcmdhd)
- [ ] Set honest build fingerprint (not spoofed Pixel 5)
- [ ] Remove `androidboot.selinux=permissive` from kernel cmdline after bring-up
