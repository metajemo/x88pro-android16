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
