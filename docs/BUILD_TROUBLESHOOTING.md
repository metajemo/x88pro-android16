# Build Troubleshooting Guide — X88 Pro Android 16

This document captures every issue encountered during the Phase 4 build
bring-up and how to fix them. If your build fails, check here first.

---

## Issue 1: `Cannot locate config makefile for product "aosp_x88pro"`

**Error:**
```
build/make/core/product_config.mk:226: error: Cannot locate config makefile for product "aosp_x88pro".
```

**Cause:** Two sub-issues:

**A) Product makefile must be named `aosp_x88pro.mk`** — not `device.mk`.
AOSP matches the product name from the filename listed in `PRODUCT_MAKEFILES`.

**Fix A:** Create `device/rockchip/x88pro/aosp_x88pro.mk` (rename from device.mk).
Update `AndroidProducts.mk`:
```makefile
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/aosp_x88pro.mk
```

**B) Device tree must be a real copy in AOSP, not a symlink.**
AOSP's product scanner does not reliably follow symlinks.

**Fix B:**
```bash
# Remove symlink if present
rm -f aosp/device/rockchip/x88pro

# Hard copy instead
cp -r device/rockchip/x88pro aosp/device/rockchip/x88pro

# Clear module paths cache
rm -f aosp/out/.module_paths/*.list
```

---

## Issue 2: `trunk_staging` release config not found

**Error:**
```
panic: Missing config trunk_staging.  Trace=[trunk_staging]
```

**Cause:** `trunk_staging` is only available in `aosp-main` (development branch).
The stable release branch `android-16.0.0_r1` only has: `bp2a`, `ap2a`, `ap3a`,
`ap4a`, `bp1a`.

**Fix:** Use `bp2a` in `AndroidProducts.mk` and lunch:
```makefile
COMMON_LUNCH_CHOICES := \
    aosp_x88pro-bp2a-eng \
    aosp_x88pro-bp2a-userdebug
```
```bash
lunch aosp_x88pro-bp2a-eng
```

---

## Issue 3: `Incorrect TARGET_2ND_ARCH_VARIANT, armv8-a`

**Error:**
```
build/make/core/combo/TARGET_linux-arm.mk:47: error: Incorrect TARGET_2ND_ARCH_VARIANT, armv8-a. Use armv8-2a instead.
```

**Cause:** Android 16 requires `armv8-2a` for the 32-bit secondary arch variant.

**Fix:** In `BoardConfig.mk`:
```makefile
# Wrong:
TARGET_2ND_ARCH_VARIANT := armv8-a
# Correct:
TARGET_2ND_ARCH_VARIANT := armv8-2a
```

---

## Issue 4: soong_build `Killed` (OOM)

**Error:**
```
Killed
ninja: build stopped: subcommand failed.
```

**Cause:** `soong_build` uses up to **29GB RAM** during ninja file generation.
On a 32GB machine this can trigger the OOM killer when other processes
are also consuming memory.

**Fix:** Increase swap space significantly:
```bash
sudo swapoff /swapfile
sudo rm /swapfile
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

Also run with fewer parallel jobs to reduce memory pressure:
```bash
m -j4    # safer on 32GB
m -j12   # ok once soong phase is done
```

**Note:** soong_build is a single-process phase — `-j` does not help here.
It needs ~29GB peak RAM regardless of job count.

---

## Issue 5: `overriding commands for target` (conflicting vendor blobs)

**Error:**
```
build/make/core/Makefile:146: error: overriding commands for target
`out/target/product/x88pro/vendor/lib64/libdrm.so',
previously defined at out/soong/installs-aosp_x88pro.mk:212185
```

**Cause:** Some of our vendor blobs are also built from source by AOSP.
Including them in `PRODUCT_COPY_FILES` causes a conflict.

**Confirmed conflicting libs (remove from aosp_x88pro.mk):**

| Library | AOSP Source Location |
|---|---|
| `libdrm.so` | `external/libdrm` |
| `audio.r_submix.default.so` | `frameworks/av/services/audiopolicy` |
| `audio.usb.default.so` | `hardware/libhardware/modules/usbaudio` |
| `android.hardware.audio@6.0-impl.so` | `hardware/interfaces/audio` |
| `android.hardware.audio.effect@6.0-impl.so` | `hardware/interfaces/audio/effect` |
| `android.hardware.bluetooth@1.0-impl.so` | `hardware/interfaces/bluetooth` |
| `android.hardware.health@2.0-impl-2.1.so` | `hardware/interfaces/health` |
| `android.hardware.memtrack@1.0-impl.so` | `hardware/interfaces/memtrack` |
| `android.hardware.tv.cec@1.0-impl.so` | `hardware/interfaces/tv/cec` |
| `libkeymaster4support.so` | `system/keymaster` |

**Fix:** Run the conflict detection script:
```bash
python3 << 'EOF'
import re

with open('aosp/out/soong/installs-aosp_x88pro.mk', 'r') as f:
    soong_content = f.read()

aosp_libs = set(re.findall(
    r'vendor/(?:lib64|lib)/(?:hw/)?([a-zA-Z0-9_.@+\-]+\.so)',
    soong_content
))

with open('aosp/device/rockchip/x88pro/aosp_x88pro.mk', 'r') as f:
    our_mk = f.read()

conflicts = []
lines = our_mk.split('\n')
new_lines = []

for line in lines:
    if 'proprietary' in line and '.so' in line:
        match = re.search(r'/([a-zA-Z0-9_.@+\-]+\.so)\s*$', line.rstrip(' \\'))
        if match and match.group(1) in aosp_libs:
            conflicts.append(match.group(1))
            continue
    new_lines.append(line)

with open('aosp/device/rockchip/x88pro/aosp_x88pro.mk', 'w') as f:
    f.write('\n'.join(new_lines))

print(f"Removed {len(conflicts)} conflicts: {sorted(conflicts)}")
EOF
```

**Important:** After removing conflicts, also update the source copy:
```bash
cp aosp/device/rockchip/x88pro/aosp_x88pro.mk \
   device/rockchip/x88pro/aosp_x88pro.mk
```

---

## Issue 6: soong bootstrap Go panic

**Error:**
```
panic: runtime error: ...
goroutine ... github.com/google/blueprint.parallelVisit...
soong bootstrap failed with: exit status 1
```

**Cause:** Soong state is corrupted — usually from modifying device files
while a build is in progress, or from a previous failed build.

**Fix:** Clean soong state and rebuild:
```bash
rm -rf aosp/out/soong/
rm -rf aosp/out/.module_paths/
# Then retry build
```

---

## Issue 7: javac pointing to Java 21 instead of Java 17

**Symptom:** Build fails with Java compatibility errors, or wrong Java version
used for compilation.

**Cause:** Ubuntu may have multiple Java versions installed with `javac`
defaulting to Java 21.

**Fix:**
```bash
sudo update-alternatives --set javac \
    /usr/lib/jvm/java-17-openjdk-amd64/bin/javac
sudo update-alternatives --set jar \
    /usr/lib/jvm/java-17-openjdk-amd64/bin/jar
sudo update-alternatives --set jarsigner \
    /usr/lib/jvm/java-17-openjdk-amd64/bin/jarsigner

# Verify
javac -version  # should show 17.x.x
```

---

## Issue 8: Missing build dependencies (Ubuntu 24.04)

**Symptom:** Various build tools not found or kernel menuconfig fails.

**Cause:** Ubuntu 24.04 renamed several packages from the `*5` suffix to `*6`.

**Fix:**
```bash
sudo apt-get install -y \
    libncurses-dev \
    libncurses6 \
    libncursesw6 \
    libtinfo6 \
    gperf \
    lib32ncurses-dev \
    lib32stdc++6 \
    lib32z1 \
    libreadline-dev \
    libghc-zlib-dev
```

**Note:** `libncurses5`, `libncursesw5`, `libtinfo5` do NOT exist in Ubuntu 24.04.

---

## Issue 9: ccache not persisting between sessions

**Symptom:** ccache shows 0% hit rate on every build start.

**Cause:** `CCACHE_DIR` not set persistently.

**Fix:**
```bash
mkdir -p ~/.ccache
ccache -M 50G
echo 'export USE_CCACHE=1' >> ~/.bashrc
echo 'export CCACHE_DIR=$HOME/.ccache' >> ~/.bashrc
echo 'export CCACHE_EXEC=$(which ccache)' >> ~/.bashrc
source ~/.bashrc
```

---

## Recommended Build Sequence

```bash
# 1. Prerequisites
cd ~/workspace/x88pro-android16

# 2. Copy device tree into AOSP (must be real copy, not symlink)
rm -f aosp/device/rockchip/x88pro
cp -r device/rockchip/x88pro aosp/device/rockchip/x88pro

# 3. Symlink BSP kernel
mkdir -p aosp/kernel
ln -sfn $(pwd)/kernel/rockchip-bsp aosp/kernel/rockchip-bsp

# 4. Set up ccache
export USE_CCACHE=1
export CCACHE_DIR=$HOME/.ccache
mkdir -p $CCACHE_DIR
ccache -M 50G

# 5. Increase swap (required for 32GB machines)
# sudo fallocate -l 16G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile

# 6. Fix Java
sudo update-alternatives --set javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac

# 7. Source and lunch
cd aosp
source build/envsetup.sh
lunch aosp_x88pro-bp2a-eng

# 8. Build (use -j4 for safety on 32GB RAM)
m -j4 2>&1 | tee ../build_log.txt
```

---

## Build Time Estimates

| Hardware | First Build | Incremental (ccache) |
|---|---|---|
| 12 cores, 32GB RAM, NVMe | 3-5 hours | 30-60 min |
| 8 cores, 16GB RAM, SSD | 6-8 hours | 45-90 min |
| 4 cores, 16GB RAM, HDD | 10-14 hours | 2-3 hours |

**Note:** soong_build (ninja generation) uses ~29GB RAM regardless of `-j`.
Always use `-j4` or lower on 32GB machines to avoid OOM during compilation.

---

## Issue 10: Repeated `overriding commands` errors (iterative conflicts)

**Pattern:** Build fails with conflict, you remove it, build again, new conflict appears.

**Cause:** AOSP provides thousands of vendor files from source. Our initial
conflict detection only runs after soong completes — but ckati fails before
all conflicts are known. Each build pass reveals new conflicts.

**Known additional conflicts discovered iteratively:**

| File | Type |
|---|---|
| `android.hardware.audio.service` | bin/hw |
| `android.hardware.media.omx@1.0-service` | bin/hw |
| `android.hardware.bluetooth@1.0-service` | bin/hw |
| `android.hardware.health@2.1-service` | bin/hw |
| `android.hardware.tv.cec@1.0-service` | bin/hw |
| `wpa_supplicant.conf` | etc/wifi |
| `wpa_supplicant_overlay.conf` | etc/wifi |
| `p2p_supplicant_overlay.conf` | etc/wifi |

**Fix:** After each conflict failure, run:
```bash
cd aosp
python3 << 'PYEOF'
import re, shutil
with open('out/soong/installs-aosp_x88pro.mk') as f:
    soong = f.read()
# Get all AOSP vendor filenames
aosp = set(p.split('/')[-1] for p in re.findall(r'vendor/[^\s:"\\]+', soong))
# Also catch base_rules conflicts from build log
with open('../build_log.txt') as f:
    log = f.read()
for c in re.findall(r"vendor/(?:[^/']+/)*([^/']+)'", log):
    aosp.add(c)
mk = 'device/rockchip/x88pro/aosp_x88pro.mk'
with open(mk) as f:
    lines = f.readlines()
removed = []
new = []
for line in lines:
    if 'proprietary' in line:
        m = re.search(r'/([a-zA-Z0-9_.@+\-]+)\s*$', line.rstrip(' \\\n'))
        if m and m.group(1) in aosp:
            removed.append(m.group(1))
            continue
    new.append(line)
with open(mk, 'w') as f:
    f.writelines(new)
shutil.copy(mk, '../device/rockchip/x88pro/aosp_x88pro.mk')
print(f"Removed {len(removed)}: {removed}")
PYEOF
```
Then soft clean and rebuild:
```bash
rm -f out/build-aosp_x88pro.ninja out/build-aosp_x88pro.ninja.lock
m -j4 2>&1 | tee ../build_log.txt
```
Repeat until no more conflicts.

---

## Issue 11: `kernel missing and no known rule to make it`

**Error:**
`````
ninja: 'out/target/product/x88pro/kernel', needed by
'out/target/product/x88pro/obj/PACKAGING/check_vintf_all_intermediates/kernel_configs.txt',
missing and no known rule to make it
`````

**Cause:** AOSP expects the BSP kernel to be built before the AOSP build.
The kernel Image must exist at `out/target/product/x88pro/kernel`.

**Fix:** Build the BSP kernel first:
`````bash
cd kernel/rockchip-bsp

# Configure
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- rockchip_defconfig

# Apply X88 Pro overlay
./scripts/kconfig/merge_config.sh -m .config \
    ../../device/rockchip/x88pro/kernel-config-x88pro.config

# Build (use all cores - kernel build is not memory intensive)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs
`````

Then restart the AOSP build:
`````bash
cd ../../aosp
rm -f out/build-aosp_x88pro.ninja out/build-aosp_x88pro.ninja.lock
m -j4 2>&1 | tee ../build_log.txt
`````

**Note:** The kernel build takes ~15-30 minutes on 12 cores.

---

## Issue 12: `neverallow` in vendor sepolicy conflicts with AOSP core policy

**Error:**
```
neverallow check failed at recovery_sepolicy.cil from device/rockchip/x88pro/sepolicy/rknn_server.te:44
  (neverallow base_typeattr_1025 rknn_server_exec (file (execute execute_no_trans)))
    allow at ... (allow domain vendor_file_type (file (... execute ...)))
    allow at ... (allow overlay_remounter vendor_file_type (file (... execute_no_trans ...)))
Failed to generate binary
Failed to build policydb
```

**Cause:** A `neverallow` rule in a vendor `.te` file conflicts with existing
`allow` rules in AOSP core policy. In this case, `domain` (all domains) already
has broad `execute` rights on `vendor_file_type`, and `overlay_remounter` has
`execute_no_trans`. Vendor policy cannot introduce `neverallow` rules that
contradict AOSP's own `allow` rules.

**Fix:** Remove the `neverallow` from the vendor `.te` file. Vendor sepolicy
cannot restrict permissions that AOSP core policy already grants globally.

```bash
# After editing the .te file:
rsync -av device/rockchip/x88pro/sepolicy/ aosp/device/rockchip/x88pro/sepolicy/
rm -f aosp/out/build-aosp_x88pro.ninja aosp/out/build-aosp_x88pro.ninja.lock
cd aosp && m -j4 2>&1 | tee ../build_log.txt
```

---

## Issue 13: `error: found duplicate sysprop assignments`

**Error:**
```
FAILED: out/target/product/x88pro/vendor/build.prop
error: found duplicate sysprop assignments:
ro.board.platform=rk356x
ro.board.platform=rk3566
error: found duplicate sysprop assignments:
ro.product.board=
ro.product.board=rk30sdk
```

**Cause:** Android 16's `post_process_props` rejects properties defined more than
once in the same partition. The properties `ro.board.platform` and `ro.product.board`
were set in two places:

1. `ADDITIONAL_VENDOR_PROPERTIES` — automatically populated by the build system
   from `TARGET_BOARD_PLATFORM` (BoardConfig.mk) and other board variables
2. `PRODUCT_PROPERTY_OVERRIDES` in `aosp_x88pro.mk` — manually added

**Fix:** Remove the duplicate entries from `PRODUCT_PROPERTY_OVERRIDES` in
`aosp_x88pro.mk`. The build system already sets these from `BoardConfig.mk`:

```makefile
# Remove these lines from PRODUCT_PROPERTY_OVERRIDES:
#   ro.product.board=rk30sdk     <- set by ADDITIONAL_VENDOR_PROPERTIES
#   ro.board.platform=rk3566     <- set by ADDITIONAL_VENDOR_PROPERTIES
```

After editing, soft clean and restart:
```bash
rsync -av device/rockchip/x88pro/ aosp/device/rockchip/x88pro/
rm -f aosp/out/build-aosp_x88pro.ninja aosp/out/build-aosp_x88pro.ninja.lock
cd aosp && m -j4 2>&1 | tee ../build_log.txt
```

**Note:** This failure occurs at ~87% after a long compile — ninja resumes
incrementally so the restart is fast (only vendor image needs regenerating).

---

## Issue 14: `found ELF prebuilt in PRODUCT_COPY_FILES`

**Error:**
```
out/target/product/x88pro/vendor/bin/hw/android.hardware.drm@1.3-service.widevine: error:
found ELF prebuilt in PRODUCT_COPY_FILES, use cc_prebuilt_binary /
cc_prebuilt_library_shared instead.
```

**Cause:** Android 16 enforces that ELF files (binaries and `.so` shared libraries)
cannot be installed via `PRODUCT_COPY_FILES`. They must be declared as
`cc_prebuilt_binary` or `cc_prebuilt_library_shared` modules in `Android.bp`.
Kernel modules (`.ko`) must use `prebuilt_etc`.

**Fix:** Create `device/rockchip/x88pro/Android.bp` with all prebuilt ELF modules,
then reference them via `PRODUCT_PACKAGES` in `aosp_x88pro.mk`.

Example for a binary:
```
cc_prebuilt_binary {
    name: "android.hardware.drm@1.3-service.widevine",
    vendor: true,
    srcs: ["proprietary/bin/android.hardware.drm@1.3-service.widevine"],
    compile_multilib: "64",
    relative_install_path: "hw",
    strip: { none: true },
    check_elf_files: false,
}
```

Example for a shared library:
```
cc_prebuilt_library_shared {
    name: "libGLES_mali",
    vendor: true,
    srcs: ["proprietary/lib64/egl/libGLES_mali.so"],
    compile_multilib: "64",
    relative_install_path: "egl",
    strip: { none: true },
    check_elf_files: false,
}
```

Example for a kernel module:
```
prebuilt_etc {
    name: "bcmdhd.ko",
    vendor: true,
    src: "proprietary/modules/bcmdhd.ko",
    sub_dir: "modules",
}
```

**Note:** `check_elf_files: false` is required for blobs from Android 11 — their
dependency graph does not match Android 16 libraries. Non-ELF files (firmware
`.bin`, `.hcd`, `.txt`, `.rc`, `.xml`) remain in `PRODUCT_COPY_FILES`.

---

## Issue 15: `No user specified for service` (host_init_verifier)

**Error:**
```
host_init_verifier: device/rockchip/x88pro/proprietary/etc/init.rknn_server.rc: 6:
No user specified for service 'rknn_server', so it would have been root.
host_init_verifier: Failed to parse init scripts with 1 error(s).
```

**Cause:** Android 16's `host_init_verifier` requires every `service` block in
init.rc files to explicitly declare a `user` directive. Services that previously
defaulted to root silently now fail at build time.

**Fix:** Add `user` and `group` to the service block:
```
service rknn_server /vendor/bin/rknn_server
    class core
    user system
    group system
    seclabel u:r:rknn_server:s0
    disabled
```

**Note:** If the init.rc file is inside `proprietary/` (gitignored), move it to
the device tree proper (e.g., `device/rockchip/x88pro/init.rknn_server.rc`) so
the fix can be committed. Config files do not belong in `proprietary/`.

---

## Issue 16: `system.img` out of space during packaging

**Error:**
```
common.ExternalError: Failed to run command '['mkuserimg_mke2fs', ...]' (exit code 4):
__populate_fs: Could not allocate block in ext2 filesystem while writing file "SystemUI.apk"
e2fsdroid: Could not allocate block in ext2 filesystem while populating file system

Out of space? Out of inodes? The tree size of ... is 1183424512 bytes (1128 MB),
with reserved space of 0 bytes (0 MB).
The max image size for filesystem files is 1139335168 bytes (1086 MB),
out of a total partition size of 1157693440 bytes (1104 MB).
```

**Cause:** `BOARD_SYSTEMIMAGE_PARTITION_SIZE` was sized based on the Android 11
stock partition layout. Android 16's system content (~1128 MB) exceeds it.

**Fix:** Increase `BOARD_SYSTEMIMAGE_PARTITION_SIZE` in `BoardConfig.mk`.
Check that the super partition has sufficient headroom first:
```
# Sum all dynamic partition sizes and compare to BOARD_SUPER_PARTITION_SIZE
# Super has ~703MB free on this device — plenty of room to grow system
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 1291911168  # ~1.2GB (was 1.1GB)
```
Then sync to AOSP tree and rebuild: `m -j4` (ninja resumes incrementally).

---

## Issue 17: `checkvintf` cannot fetch vendor manifest

**Error:**
```
FAILED: out/target/product/x88pro/obj/PACKAGING/check_vintf_all_intermediates/check_vintf_vendor.log
[INFO] Fetch 'out/target/product/x88pro/vendor/etc/vintf/manifest.xml': NAME_NOT_FOUND
[INFO] Fetch 'out/target/product/x88pro/vendor/manifest.xml': NAME_NOT_FOUND
getDeviceHalManifest: -2 VINTF parse error: Cannot read out/target/product/x88pro/vendor/manifest.xml
ERROR: Cannot fetch vendor manifest.
```

**Cause:** The vendor VINTF manifest (`manifest.xml`) existed in
`proprietary/etc/vintf/manifest.xml` but was never declared to the build system.
`DEVICE_MANIFEST_FILE` was missing from `BoardConfig.mk`, so the file was never
installed into the vendor partition output.

**Fix:** Add to `BoardConfig.mk`:
```makefile
DEVICE_MANIFEST_FILE := device/rockchip/x88pro/vintf/manifest.xml
```
Create the manifest at that path (not in `proprietary/` — it's gitignored and not a blob).
Then sync to AOSP tree and rebuild: `m -j4` (ninja resumes incrementally).

---

## Issue 18: VINTF manifest incompatible with Android 16 framework

**Error:**
```
ERROR: files are incompatible: Runtime info and framework compatibility matrix are incompatible:
Kernel FCM Version is 5 and kernel version is 5.10.226, but the first kernel FCM version
allowed for kernel version 5.10.y is 6
The following instances are in the device manifest but not specified in framework compatibility matrix:
    android.hardware.memtrack@1.0::IMemtrack/default
INCOMPATIBLE
```

**Cause:** The Android 11 stock VINTF manifest (`target-level="5"`) is incompatible with
Android 16 in two ways:
1. `<kernel target-level="5"/>` — kernel 5.10.y ships with Android 12 (FCM level 6).
   FCM 5 (Android 11) is too low; checkvintf rejects it.
2. `android.hardware.memtrack@1.0` — this HAL was removed from all FCM 6+ compatibility
   matrices. It was superseded by AIDL `IMemtrack` in Android 12.

**Fix:** Update `device/rockchip/x88pro/vintf/manifest.xml`:
- Change `<manifest ... target-level="5">` → `target-level="6"`
- Change `<kernel target-level="5"/>` → `<kernel target-level="6"/>`
- Remove the entire `android.hardware.memtrack@1.0` HAL block

**Note:** This issue is a cascade from Issue 17. The manifest needed to exist (Issue 17)
before checkvintf could report these compatibility problems.

---

## Issue 19: Kernel config incompatible with FCM 6 requirements

**Error:**
```
ERROR: files are incompatible: Runtime info and framework compatibility matrix are incompatible:
No compatible kernel requirement found (kernel FCM version = 6).
For kernel requirements at matrix level 6, Kernel config errors:
    For config CONFIG_DEVMEM, value = y but required n
    Missing config CONFIG_TRACE_GPU_MEM
INCOMPATIBLE
```

**Cause:** Once the manifest `target-level` is raised to 6 (required for kernel 5.10.y),
checkvintf also validates kernel configs against the FCM 6 requirements. The Rockchip BSP
kernel predates these requirements:
- `CONFIG_DEVMEM=y` — BSP needs `/dev/mem`; FCM 6 security hardening requires `=n`
- `CONFIG_TRACE_GPU_MEM` — tracing feature not present in Rockchip BSP defconfig

Patching the BSP kernel for these would risk breaking hardware functionality.

**Fix:** Disable kernel VINTF enforcement in `device.mk`:
```makefile
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false
```
This is appropriate for engineering bring-up on a vendor BSP kernel.
OTA compliance is not a goal for this build.

---

## Issue 20: `super.img` not produced by build

**Symptom:** Build succeeds but only individual partition images exist
(`system.img`, `vendor.img`, `product.img`, `odm.img`). No `super.img` in
`out/target/product/x88pro/`.

**Cause:** `PRODUCT_BUILD_SUPER_PARTITION` is derived from `PRODUCT_USE_DYNAMIC_PARTITIONS`.
If neither is set in the product makefile, the build assembles the individual images
but never calls `lpmake` to combine them into `super.img`. `BoardConfig.mk` having
`BOARD_SUPER_PARTITION_SIZE` is not sufficient — the product variable must also be set.

**Fix:** Add to `aosp_x88pro.mk`:
```makefile
PRODUCT_USE_DYNAMIC_PARTITIONS := true
```
Then rebuild: `m superimage` (fast — just the assembly step, no recompilation).

---

## Issue 21: Changes to `device.mk` have no effect

**Symptom:** Product variables set in `device.mk` are silently ignored. The build
uses stale values even after editing the file and resyncing to the AOSP tree.

**Cause:** `AndroidProducts.mk` declares `aosp_x88pro.mk` as the product file.
`device.mk` exists in the repo but is **never included** by any makefile. It is
dead code left over from an earlier project structure. The build system only reads
`aosp_x88pro.mk`.

**Fix:** Make all product variable changes in `aosp_x88pro.mk`, not `device.mk`.

**Secondary symptom:** If the fix is in the right file but the ninja rule still shows
the old value, delete `out/build-aosp_x88pro.ninja` to force regeneration:
```bash
rm out/build-aosp_x88pro.ninja
m -j4
```

---

## Issue 22: CONFIG_FORTIFY_SOURCE breaks Mali Bifrost CSF driver build

**Symptom:** Enabling `CONFIG_FORTIFY_SOURCE=y` in the BSP kernel causes a
compile error in the Mali Bifrost driver:

```
In function 'memcmp',
    inlined from 'kbase_csf_firmware_load_init' at
    drivers/gpu/arm/bifrost/csf/mali_kbase_csf_firmware.c:2569:6:
./include/linux/string.h:427:25: error: call to '__read_overflow' declared with
    attribute error: detected read beyond size of object passed as 1st parameter
```

**Cause:** `drivers/gpu/arm/bifrost/csf/mali_kbase_csf_firmware.c` declares
the linker-generated firmware boundary symbols as `extern char`:

```c
extern char mali_csffw;
extern char mali_csffw_end;
```

This tells the compiler that `mali_csffw` is a single-byte object. Within
`kbase_csf_firmware_load_init()`, the compiler traces `mcu_fw->data` back to
`(u8 *)(&mali_csffw)` and determines the object has size 1. The subsequent
`memcmp(mcu_fw->data, &magic, sizeof(u32))` then reads 4 bytes from a 1-byte
object — FORTIFY_SOURCE catches this as a read overflow at compile time.

**Rockchip's workaround:** Ship BSP with `# CONFIG_FORTIFY_SOURCE is not set`,
silencing the error without fixing the driver.

**Fix:** Declare the linker boundary symbols as incomplete array types (standard
Linux kernel idiom — `__builtin_object_size` returns -1 for incomplete arrays,
so FORTIFY_SOURCE cannot determine a bound to check against):

```c
/* Before */
extern char mali_csffw;
extern char mali_csffw_end;

/* After */
extern char mali_csffw[];
extern char mali_csffw_end[];
```

Also update the pointer arithmetic and cast to remove the now-incorrect `&`:

```c
/* Before */
mcu_fw->size = &mali_csffw_end - &mali_csffw;
mcu_fw->data = (u8 *)(&mali_csffw);

/* After */
mcu_fw->size = mali_csffw_end - mali_csffw;
mcu_fw->data = (u8 *)mali_csffw;
```

After this patch, `CONFIG_FORTIFY_SOURCE=y` compiles cleanly. Rebuild kernel
and boot.img after applying.

**Files changed:**
- `kernel/rockchip-bsp/drivers/gpu/arm/bifrost/csf/mali_kbase_csf_firmware.c`
- `device/rockchip/x88pro/kernel-config-x88pro.config` (re-enable FORTIFY_SOURCE)

---

## Issue 23: WIFI_DRIVER_MODULE_PATH points to wrong bcmdhd.ko location

**Symptom:** WiFi fails to initialize on first boot. `logcat` shows the WiFi
HAL or `wpa_supplicant` failing to `insmod` the bcmdhd driver.

**Cause:** `prebuilt_etc` in Android.bp installs `bcmdhd.ko` to:
```
/vendor/etc/modules/bcmdhd.ko    ← where the file actually is
```
But `WIFI_DRIVER_MODULE_PATH` in `BoardConfig.mk` was set to:
```
/vendor/lib/modules/bcmdhd.ko    ← wrong path, file not here
```

The stock Android 11 device stores bcmdhd.ko in `/vendor/lib/modules/`, which
is where the original value came from. However, `prebuilt_etc` always installs
to the `etc/` directory of the partition, not `lib/`. There is no `prebuilt_etc`
equivalent that targets `lib/modules/`.

**Fix:** Update `WIFI_DRIVER_MODULE_PATH` in `BoardConfig.mk` to match the
actual install location:
```makefile
WIFI_DRIVER_MODULE_PATH := /vendor/etc/modules/bcmdhd.ko
```

**Files changed:**
- `device/rockchip/x88pro/BoardConfig.mk`
- `device/rockchip/x88pro/Android.bp` (comment fix)

**Detected by:** Pre-flash vendor.img audit (debugfs + direct vendor/ directory inspection).

---

## Issue 24: bcmdhd.ko compiled for kernel 4.19 — fails to load on 5.10

**Symptom:** WiFi fails on first boot. `dmesg` shows:
```
bcmdhd: disagrees about version of symbol ...
```
or simply the insmod call returning an error.

**Cause:** The `bcmdhd.ko` extracted from stock Android 11 firmware has
`vermagic: 4.19.172`. Linux kernel refuses to load any module whose vermagic
does not exactly match the running kernel version (`5.10.226`).

Note: `CONFIG_BCMDHD=y` in the kernel config is a **bool parent gate** (not a
driver). The actual AP6398S driver is `CONFIG_AP6XXX=m` (module) in
`drivers/net/wireless/rockchip_wlan/rkwifi/bcmdhd/`. The stock `.ko` was the
wrong one for both kernel version and driver path.

**Fix:** Build `bcmdhd.ko` from the BSP 5.10 source:
```bash
cd kernel/rockchip-bsp
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j12 \
  drivers/net/wireless/rockchip_wlan/rkwifi/bcmdhd/bcmdhd.ko
```
Two `-Werror=address` patches required first (always-true pointer checks on
`rev_info_delim + 1` in `wl_android.c` and `wl_android_ext.c`).

Replace `device/rockchip/x88pro/proprietary/modules/bcmdhd.ko` with the
output. New vermagic: `5.10.226 SMP preempt mod_unload modversions aarch64`.

---

## Issue 25: WiFi firmware generic names never installed (PRODUCT_SYMLINKS silent no-op)

**Symptom:** bcmdhd driver loads but firmware request fails. `dmesg` shows:
```
bcmdhd: firmware: failed to load fw_bcmdhd.bin
```

**Cause:** `PRODUCT_SYMLINKS` is not a real Android build variable. It is
silently ignored by the build system. The entries in `aosp_x88pro.mk` intended
to symlink `fw_bcmdhd.bin` → `fw_bcm4359c0_ag.bin` and `nvram.txt` →
`nvram_ap6398s.txt` were never processed. Only the chip-specific filenames
were installed.

The kernel config and BoardConfig.mk both reference the generic names:
- `CONFIG_BCMDHD_FW_PATH="/vendor/etc/firmware/fw_bcmdhd.bin"`
- `WIFI_DRIVER_FW_PATH_STA := /vendor/etc/firmware/fw_bcmdhd.bin`

**Fix:** Replace `PRODUCT_SYMLINKS` with additional `PRODUCT_COPY_FILES` entries
using the generic destination names (copies work identically to symlinks for firmware):
```makefile
PRODUCT_COPY_FILES += \
    .../fw_bcm4359c0_ag.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcmdhd.bin \
    .../fw_bcm4359c0_ag_apsta.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcmdhd_apsta.bin \
    .../fw_bcm4359c0_ag_p2p.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcmdhd_p2p.bin \
    .../nvram_ap6398s.txt:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/nvram.txt
```

---

## Issue 26: Bluetooth HAL service binary stranded in dead device.mk

**Symptom:** Bluetooth HAL declared in VINTF manifest but service never starts.
`logcat` shows `android.hardware.bluetooth@1.0-service` missing.

**Cause:** `android.hardware.bluetooth@1.0-service` was only referenced in
`device.mk` via `PRODUCT_COPY_FILES`. Since `device.mk` is never included by
the build (dead code — see Issue 21), the binary was never installed to
`/vendor/bin/hw/`.

**Fix:** Add to `Android.bp` as `cc_prebuilt_binary` and add the module name
to `PRODUCT_PACKAGES` in `aosp_x88pro.mk`.

---

## Note: device tree changes require rsync to AOSP tree

`device/rockchip/x88pro/` (workspace root) is the git-tracked source of truth.
The AOSP build reads from `aosp/device/rockchip/x88pro/` — a separate copy.

After any change to the device tree, sync it before rebuilding:
```bash
rsync -a --checksum device/rockchip/x88pro/ aosp/device/rockchip/x88pro/
```

This is run automatically by `scripts/phase4_build.sh` but not by incremental
`m` commands. If a fix appears to have no effect on the build, this is the
first thing to check.


---

## Issue 27: dhd_static_buf.ko missing — bcmdhd dependency not installed

**Symptom:** bcmdhd fails to load on boot with `Unknown symbol` errors or
`insmod: ERROR: could not insert module` if `modprobe` is used.

**Cause:** `modinfo bcmdhd.ko` shows `depends: dhd_static_buf`. The dependency
module `dhd_static_buf.ko` was built alongside `bcmdhd.ko` in the BSP kernel
tree but was not copied into `proprietary/modules/` and not declared in
`Android.bp`. It was therefore absent from `vendor.img`.

**Fix:**
1. Copy `dhd_static_buf.ko` from the kernel build output into `proprietary/modules/`:
   ```bash
   cp kernel/rockchip-bsp/drivers/net/wireless/rockchip_wlan/rkwifi/bcmdhd/dhd_static_buf.ko \
      device/rockchip/x88pro/proprietary/modules/
   ```
2. Add to `Android.bp` as `prebuilt_etc` with `sub_dir: "modules"`.
3. Add `dhd_static_buf.ko` to `PRODUCT_PACKAGES` in `aosp_x88pro.mk`.
4. Add SELinux label in `sepolicy/file_contexts`:
   `/vendor/etc/modules/dhd_static_buf\.ko  u:object_r:vendor_file:s0`

---

## Issue 28: libdrm.so missing from vendor partition

**Symptom:** Graphics allocator HAL (`android.hardware.graphics.allocator@4.0`)
crashes at startup; `logcat` shows `dlopen failed: library "libdrm.so" not found`.

**Cause:** `libdrm.so` was present in `proprietary/lib64/` and referenced in
the dead `device.mk` via `PRODUCT_COPY_FILES`. Since `device.mk` is never
included (see Issue 21), the library was never installed to `/vendor/lib64/`.
It was also absent from `Android.bp`.

**Fix:** Add to `Android.bp` as `cc_prebuilt_library_shared` and add `libdrm`
to `PRODUCT_PACKAGES` in `aosp_x88pro.mk`.

---

## Issue 29: SELinux file_contexts references wrong bcmdhd.ko path

**Symptom:** SELinux audit log noise — `avc: denied { read } for
path="/vendor/etc/modules/bcmdhd.ko" scontext=... tcontext=u:object_r:vendor_file:s0`
is NOT the real error; the actual problem is the context is applied to the
wrong path.

**Cause:** `sepolicy/file_contexts` had `/vendor/lib/modules/bcmdhd.ko` but
`prebuilt_etc` installs to `/vendor/etc/modules/bcmdhd.ko` (Issue 23 fixed
the BoardConfig path but not the SELinux label).

**Fix:** Update `file_contexts` to reference `/vendor/etc/modules/bcmdhd.ko`
and add `/vendor/etc/modules/dhd_static_buf.ko`.

---

## Issue 30: HAL service init.rc files never installed — services never start at boot

**Symptom:** After first boot, `adb shell getprop | grep "init.svc"` shows
keymaster, gatekeeper, Bluetooth, DRM, power, lights, and neural networks
services not running. Framework attempts to bind to these HALs and gets
`No such file or directory` or `Transport is closed`.

**Cause:** Vendor prebuilt service binaries declared as `cc_prebuilt_binary`
in `Android.bp` do NOT have embedded init.rc files (unlike AOSP source-built
binaries which use `init_rc:` in their Android.bp). The corresponding .rc files
were present in `proprietary/etc/init/` but were never installed to the vendor
partition via `PRODUCT_COPY_FILES`.

Affected services (all PRODUCT_PACKAGES prebuilts):
- `android.hardware.bluetooth@1.0-service`
- `android.hardware.keymaster@4.0-service.optee`
- `android.hardware.gatekeeper@1.0-service.optee`
- `android.hardware.drm@1.3-service.widevine`
- `android.hardware.power-service.rockchip`
- `android.hardware.lights-service.rockchip`
- `rockchip.hardware.neuralnetworks@1.0-service`

**Fix:** Install each `.rc` from `proprietary/etc/init/` via `PRODUCT_COPY_FILES`
to `$(TARGET_COPY_OUT_VENDOR)/etc/init/` in `aosp_x88pro.mk`.

---

## Issue 31: dhd_static_buf.ko not loaded before bcmdhd — WiFi HAL insmod fails

**Symptom:** WiFi fails to enable on first boot. `logcat` shows:
```
wifi_hal: finit_module return: -1 (Unknown symbol in module)
```

**Cause:** `modinfo bcmdhd.ko` lists `depends: dhd_static_buf`. Android's
`wifi_load_driver()` in `libwifi_hal/wifi_hal_common.cpp` calls `finit_module(2)`
directly (not `modprobe`). The kernel does NOT resolve module dependencies when
using `finit_module`. If `dhd_static_buf.ko` is not already in the kernel,
bcmdhd.ko fails with an unknown symbol error.

`dhd_static_buf.ko` had no mechanism to be loaded — it was installed to
`/vendor/etc/modules/` but nothing triggered loading it at boot.

**Fix:** Create `init.bcmdhd.rc` in the device tree with an `on boot` insmod
command for `dhd_static_buf.ko`, and install it to `/vendor/etc/init/` via
`PRODUCT_COPY_FILES`. The `on boot` trigger fires before the WiFi HAL starts,
ensuring the dependency is satisfied when `wifi_load_driver()` is first called.
