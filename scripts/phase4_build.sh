#!/bin/bash
# =============================================================================
# X88 Pro RK3566 - Phase 4: Android 16 Build
# =============================================================================
# Builds Android 16 for the X88 Pro using the AOSP build system.
#
# Usage:
#   ./phase4_build.sh setup AOSP_DIR     - Prepare AOSP for x88pro build
#   ./phase4_build.sh build AOSP_DIR     - Full AOSP build
#   ./phase4_build.sh clean AOSP_DIR     - Clean build state
#
# Build times (approximate, 12 cores / 32GB RAM / NVMe):
#   First build:       3-5 hours  (no ccache)
#   Incremental:       30-60 min  (with ccache)
#
# Memory requirement:
#   soong_build uses ~29GB RAM for ninja generation.
#   32GB machines MUST have 16GB swap configured.
#   See: docs/BUILD_TROUBLESHOOTING.md
#
# Known issues and fixes: docs/BUILD_TROUBLESHOOTING.md
# =============================================================================
set -e

COMMAND="${1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}==>${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warning() { echo -e "${YELLOW}⚠${NC} $*"; }
error()   { echo -e "${RED}✗ ERROR:${NC} $*" >&2; exit 1; }

# =============================================================================
# SETUP - Prepare AOSP tree for x88pro build
# =============================================================================
# This must be run once before the first build, and again after any
# change to device/rockchip/x88pro/ files.
#
# What it does:
#   1. Validates prerequisites (Java 17, disk space, swap)
#   2. Copies device tree into AOSP (real copy, not symlink - AOSP requirement)
#   3. Symlinks BSP kernel into AOSP
#   4. Detects and removes conflicting vendor blobs
#   5. Sets up ccache
#   6. Fixes Java alternatives if needed
# =============================================================================
setup() {
    AOSP_DIR="${2:-$REPO_DIR/aosp}"

    info "Phase 4 setup for X88 Pro Android 16 build"
    info "AOSP: $AOSP_DIR"
    info "Repo: $REPO_DIR"

    [ -d "$AOSP_DIR" ] || error "AOSP directory not found: $AOSP_DIR"
    [ -f "$AOSP_DIR/build/envsetup.sh" ] || \
        error "Not an AOSP directory: $AOSP_DIR"

    # --- Check Java 17 ---
    info "Checking Java version..."
    JAVA_VER=$(java -version 2>&1 | grep -oP '"\K[0-9]+' | head -1)
    if [ "$JAVA_VER" != "17" ]; then
        warning "Java $JAVA_VER detected, switching to Java 17..."
        if [ -f "/usr/lib/jvm/java-17-openjdk-amd64/bin/java" ]; then
            sudo update-alternatives --set java \
                /usr/lib/jvm/java-17-openjdk-amd64/bin/java
            sudo update-alternatives --set javac \
                /usr/lib/jvm/java-17-openjdk-amd64/bin/javac
            sudo update-alternatives --set jar \
                /usr/lib/jvm/java-17-openjdk-amd64/bin/jar
            sudo update-alternatives --set jarsigner \
                /usr/lib/jvm/java-17-openjdk-amd64/bin/jarsigner
            success "Java 17 configured"
        else
            error "Java 17 not found. Install: sudo apt-get install openjdk-17-jdk"
        fi
    else
        success "Java 17 ✓"
    fi

    # Also check javac specifically
    JAVAC_VER=$(javac -version 2>&1 | grep -oP '[0-9]+' | head -1)
    if [ "$JAVAC_VER" != "17" ]; then
        warning "javac points to wrong version ($JAVAC_VER), fixing..."
        sudo update-alternatives --set javac \
            /usr/lib/jvm/java-17-openjdk-amd64/bin/javac 2>/dev/null || true
    fi

    # --- Check disk space ---
    info "Checking disk space..."
    AVAIL_GB=$(df -BG "$AOSP_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$AVAIL_GB" -lt 50 ]; then
        error "Insufficient disk space: ${AVAIL_GB}GB available, 50GB required"
    fi
    success "Disk space: ${AVAIL_GB}GB available ✓"

    # --- Check swap (critical for 32GB machines) ---
    info "Checking swap space..."
    SWAP_GB=$(free -g | awk '/Swap/ {print $2}')
    if [ "$SWAP_GB" -lt 8 ]; then
        warning "Only ${SWAP_GB}GB swap! soong_build needs ~29GB RAM."
        warning "Strongly recommend 16GB swap for 32GB machines."
        warning "Run: sudo fallocate -l 16G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
        warning "Continuing anyway - may fail with OOM..."
    else
        success "Swap: ${SWAP_GB}GB ✓"
    fi

    # --- Copy device tree into AOSP ---
    # IMPORTANT: Must be a real copy, NOT a symlink.
    # AOSP's product scanner does not reliably follow symlinks.
    info "Copying device tree into AOSP..."
    mkdir -p "$AOSP_DIR/device/rockchip"

    # Remove existing (symlink or old copy)
    rm -rf "$AOSP_DIR/device/rockchip/x88pro"

    # Hard copy
    cp -r "$REPO_DIR/device/rockchip/x88pro" \
        "$AOSP_DIR/device/rockchip/x88pro"

    success "Device tree copied to $AOSP_DIR/device/rockchip/x88pro"

    # Clear module paths cache so AOSP rescans
    rm -f "$AOSP_DIR/out/.module_paths/"*.list
    success "Module paths cache cleared"

    # --- Symlink BSP kernel ---
    info "Linking BSP kernel into AOSP..."
    mkdir -p "$AOSP_DIR/kernel"
    rm -f "$AOSP_DIR/kernel/rockchip-bsp"
    ln -sfn "$REPO_DIR/kernel/rockchip-bsp" \
        "$AOSP_DIR/kernel/rockchip-bsp"
    success "BSP kernel linked: $AOSP_DIR/kernel/rockchip-bsp"

    # --- Set up ccache ---
    info "Setting up ccache..."
    mkdir -p "$HOME/.ccache"
    export CCACHE_DIR="$HOME/.ccache"
    export USE_CCACHE=1
    ccache -M 50G > /dev/null 2>&1
    if ! grep -q "CCACHE_DIR" ~/.bashrc; then
        echo 'export USE_CCACHE=1' >> ~/.bashrc
        echo 'export CCACHE_DIR=$HOME/.ccache' >> ~/.bashrc
        echo 'export CCACHE_EXEC=$(which ccache)' >> ~/.bashrc
        success "ccache configured (50GB, added to ~/.bashrc)"
    else
        success "ccache already configured ✓"
    fi

    # --- Detect and remove conflicting vendor blobs ---
    # AOSP builds many HAL implementation libs from source.
    # Including them in PRODUCT_COPY_FILES causes build failure:
    # "overriding commands for target"
    # We detect conflicts by comparing against soong's install list.
    info "Checking for vendor blob conflicts with AOSP source..."

    SOONG_INSTALLS="$AOSP_DIR/out/soong/installs-aosp_x88pro.mk"
    if [ -f "$SOONG_INSTALLS" ]; then
        python3 << PYEOF
import re

with open('$SOONG_INSTALLS', 'r') as f:
    soong_content = f.read()

aosp_libs = set(re.findall(
    r'vendor/(?:lib64|lib)/(?:hw/)?([a-zA-Z0-9_.@+\-]+\.so)',
    soong_content
))

mk_path = '$AOSP_DIR/device/rockchip/x88pro/aosp_x88pro.mk'
with open(mk_path, 'r') as f:
    our_mk = f.read()

conflicts = []
lines = our_mk.split('\n')
new_lines = []

for line in lines:
    if 'proprietary' in line and '.so' in line:
        match = re.search(r'/([a-zA-Z0-9_.@+\-]+\.so)\s*$', line.rstrip(' \\\\'))
        if match and match.group(1) in aosp_libs:
            conflicts.append(match.group(1))
            continue
    new_lines.append(line)

if conflicts:
    with open(mk_path, 'w') as f:
        f.write('\n'.join(new_lines))
    print(f"Removed {len(conflicts)} conflicting libs:")
    for c in sorted(conflicts):
        print(f"  - {c}")
else:
    print("No conflicts found")
PYEOF
    else
        warning "Soong installs file not found yet (first build)."
        warning "Known conflicts already removed from aosp_x88pro.mk:"
        warning "  libdrm, audio.r_submix, audio.usb, audio@6.0-impl,"
        warning "  audio.effect@6.0-impl, bluetooth@1.0-impl,"
        warning "  health@2.0-impl, memtrack@1.0-impl, tv.cec@1.0-impl,"
        warning "  libkeymaster4support"
    fi

    echo ""
    success "Setup complete! Ready to build."
    echo ""
    echo "  Next step:"
    echo "    ./scripts/phase4_build.sh build $AOSP_DIR"
    echo ""
    echo "  Or manually:"
    echo "    cd $AOSP_DIR"
    echo "    source build/envsetup.sh"
    echo "    lunch aosp_x88pro-bp2a-eng"
    echo "    m -j4"
}

# =============================================================================
# BUILD - Full AOSP build
# =============================================================================
build() {
    AOSP_DIR="${2:-$REPO_DIR/aosp}"
    JOBS="${3:-4}"

    [ -d "$AOSP_DIR" ] || error "AOSP directory not found: $AOSP_DIR"

    # Set up ccache
    export USE_CCACHE=1
    export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"

    info "Starting Android 16 build for X88 Pro"
    info "Jobs: $JOBS (use 4 for safety on 32GB RAM)"
    info "ccache: $CCACHE_DIR ($(ccache -s 2>/dev/null | grep 'Cache size' | awk '{print $NF}') used)"

    cd "$AOSP_DIR"

    # Source environment
    source build/envsetup.sh > /dev/null 2>&1

    # Lunch
    info "Running lunch aosp_x88pro-bp2a-eng..."
    lunch aosp_x88pro-bp2a-eng || \
        error "lunch failed. Run setup first: ./scripts/phase4_build.sh setup"

    # Build
    info "Building... (this will take 3-5 hours)"
    info "Monitor: tail -f $REPO_DIR/build_log.txt"
    info "Detach:  Ctrl+A D (if running in screen)"
    echo ""

    START_TIME=$(date +%s)
    m -j"$JOBS" 2>&1 | tee "$REPO_DIR/build_log.txt"
    BUILD_STATUS=${PIPESTATUS[0]}
    END_TIME=$(date +%s)
    ELAPSED=$(( (END_TIME - START_TIME) / 60 ))

    echo ""
    if [ $BUILD_STATUS -eq 0 ]; then
        success "Build complete in ${ELAPSED} minutes!"
        echo ""
        echo "  Output images: $AOSP_DIR/out/target/product/x88pro/"
        echo "  Next: ./scripts/phase5_flash.sh flash"
    else
        error "Build failed after ${ELAPSED} minutes. Check $REPO_DIR/build_log.txt"
    fi
}

# =============================================================================
# CLEAN - Clean build state
# =============================================================================
clean() {
    AOSP_DIR="${2:-$REPO_DIR/aosp}"
    LEVEL="${3:-soft}"

    case "$LEVEL" in
        soft)
            # Remove only ninja/kati state - keeps soong cache
            # Use when: ckati errors, Makefile issues
            info "Soft clean (preserving soong cache)..."
            rm -f "$AOSP_DIR/out/build-aosp_x88pro.ninja"
            rm -f "$AOSP_DIR/out/build-aosp_x88pro.ninja.lock"
            success "Soft clean done"
            ;;
        soong)
            # Remove soong state - forces ninja regeneration
            # Use when: soong panic/crash, blueprint errors
            info "Cleaning soong state..."
            rm -rf "$AOSP_DIR/out/soong/"
            rm -rf "$AOSP_DIR/out/.module_paths/"
            success "Soong clean done (next build will regenerate ninja, ~3-5 min)"
            ;;
        full)
            # Full clean - removes everything
            # Use when: switching products, major config changes
            info "Full clean (this will take a while)..."
            cd "$AOSP_DIR"
            source build/envsetup.sh > /dev/null 2>&1
            make clean
            success "Full clean done"
            ;;
        *)
            error "Unknown clean level: $LEVEL. Use: soft | soong | full"
            ;;
    esac
}

# =============================================================================
# STATUS - Show build status and configuration
# =============================================================================
status() {
    AOSP_DIR="${2:-$REPO_DIR/aosp}"

    echo ""
    echo "=== X88 Pro Android 16 Build Status ==="
    echo ""

    # Java
    JAVA_VER=$(java -version 2>&1 | grep -oP '"\K[0-9]+' | head -1)
    JAVAC_VER=$(javac -version 2>&1 | grep -oP '[0-9]+' | head -1)
    [ "$JAVA_VER" = "17" ] && echo "✅ Java:   $JAVA_VER" || echo "❌ Java:   $JAVA_VER (need 17)"
    [ "$JAVAC_VER" = "17" ] && echo "✅ javac:  $JAVAC_VER" || echo "❌ javac:  $JAVAC_VER (need 17)"

    # Disk
    AVAIL_GB=$(df -BG "$AOSP_DIR" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')
    [ "${AVAIL_GB:-0}" -gt 50 ] && \
        echo "✅ Disk:   ${AVAIL_GB}GB free" || \
        echo "❌ Disk:   ${AVAIL_GB}GB free (need 50GB)"

    # Swap
    SWAP_GB=$(free -g | awk '/Swap/ {print $2}')
    [ "${SWAP_GB:-0}" -ge 8 ] && \
        echo "✅ Swap:   ${SWAP_GB}GB" || \
        echo "⚠️  Swap:   ${SWAP_GB}GB (recommend 16GB for soong)"

    # RAM
    RAM_GB=$(free -g | awk '/Mem/ {print $2}')
    echo "   RAM:   ${RAM_GB}GB total"

    # Device tree
    [ -d "$AOSP_DIR/device/rockchip/x88pro" ] && \
        [ ! -L "$AOSP_DIR/device/rockchip/x88pro" ] && \
        echo "✅ Device: copied into AOSP" || \
        echo "❌ Device: not found or still a symlink (run setup)"

    # BSP kernel
    [ -d "$AOSP_DIR/kernel/rockchip-bsp" ] && \
        echo "✅ Kernel: BSP linked" || \
        echo "❌ Kernel: BSP not linked (run setup)"

    # Blobs
    BLOB_COUNT=$(find "$REPO_DIR/device/rockchip/x88pro/proprietary" \
        -type f 2>/dev/null | wc -l)
    [ "$BLOB_COUNT" -gt 100 ] && \
        echo "✅ Blobs:  $BLOB_COUNT files extracted" || \
        echo "❌ Blobs:  $BLOB_COUNT files (run phase3 first)"

    # ccache
    CCACHE_USED=$(ccache -s 2>/dev/null | grep "Cache size" | awk '{print $NF}')
    echo "   ccache: ${CCACHE_USED:-0} used / 50.0 GB max"

    # Build output
    if [ -d "$AOSP_DIR/out/target/product/x88pro" ]; then
        IMGS=$(ls "$AOSP_DIR/out/target/product/x88pro/"*.img 2>/dev/null | wc -l)
        echo "   Output: $IMGS image(s) in out/target/product/x88pro/"
    fi
    echo ""
}

# =============================================================================
# Main
# =============================================================================
case "$COMMAND" in
    setup)   setup "$@" ;;
    build)   build "$@" ;;
    clean)   clean "$@" ;;
    status)  status "$@" ;;
    *)
        echo "Usage: $0 {setup|build|clean|status} [AOSP_DIR] [options]"
        echo ""
        echo "Commands:"
        echo "  setup  [AOSP_DIR]        - Prepare AOSP for x88pro build"
        echo "  build  [AOSP_DIR] [JOBS] - Full AOSP build (default: -j4)"
        echo "  clean  [AOSP_DIR] [soft|soong|full] - Clean build state"
        echo "  status [AOSP_DIR]        - Show build configuration status"
        echo ""
        echo "Examples:"
        echo "  ./scripts/phase4_build.sh setup"
        echo "  ./scripts/phase4_build.sh build . 4"
        echo "  ./scripts/phase4_build.sh clean . soong"
        echo "  ./scripts/phase4_build.sh status"
        exit 1
        ;;
esac
