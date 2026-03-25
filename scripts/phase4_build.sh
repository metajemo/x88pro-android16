#!/bin/bash
# =============================================================================
# X88 Pro RK3566 - Phase 4: Android 16 Build
# =============================================================================
# Builds Android 16 for the X88 Pro using the AOSP build system.
#
# Usage:
#   ./phase4_build.sh setup AOSP_DIR PRODUCT    - Configure build
#   ./phase4_build.sh kernel AOSP_DIR JOBS      - Build kernel only
#   ./phase4_build.sh aosp AOSP_DIR PRODUCT JOBS - Full AOSP build
#
# Build times (approximate):
#   - 8-core CPU, 32GB RAM, NVMe:  3-4 hours
#   - 4-core CPU, 16GB RAM, SSD:   6-8 hours
# =============================================================================

set -e

COMMAND="${1}"

# =============================================================================
# SETUP - Configure the build environment
# =============================================================================
# Sources AOSP's envsetup.sh and runs 'lunch' to select our build target.
#
# Expected output:
#   including device/rockchip/x88pro/AndroidProducts.mk
#   ...
#   ============================================
#   PLATFORM_VERSION_CODENAME=REL
#   PLATFORM_VERSION=16
#   TARGET_PRODUCT=rockchip_x88pro
#   TARGET_BUILD_VARIANT=userdebug
#   TARGET_ARCH=arm64
#   ============================================
setup() {
    AOSP_DIR="${2}"
    PRODUCT="${3}"

    echo "==> Setting up build environment..."
    cd "$AOSP_DIR"

    # Source the AOSP environment setup script
    # This makes build commands like 'lunch', 'm', 'mmm' available
    source build/envsetup.sh

    # Select build target:
    #   rockchip_x88pro = our device
    #   userdebug       = debug build with root access (good for development)
    #   user            = production build (use for final release)
    lunch "${PRODUCT}-userdebug"

    echo "==> Build environment configured."
    echo "    Target: ${PRODUCT}-userdebug"
    echo "    Out dir: $AOSP_DIR/out/target/product/x88pro/"
}

# =============================================================================
# KERNEL - Build the Linux kernel
# =============================================================================
# Builds the kernel separately before the full AOSP build.
# Useful for faster iteration when tweaking kernel config.
#
# Expected output (at the end):
#   LD      vmlinux
#   OBJCOPY arch/arm64/boot/Image
#   Building modules, stage 2
#   Kernel: arch/arm64/boot/Image is ready
#   Elapsed time: ~30-60 minutes
kernel() {
    AOSP_DIR="${2}"
    JOBS="${3:-$(nproc)}"

    echo "==> Building kernel with $JOBS parallel jobs..."
    cd "$AOSP_DIR"
    source build/envsetup.sh

    # Build just the kernel image
    # TODO: Confirm exact kernel build command for Rockchip Android 16
    make -j"$JOBS" ARCH=arm64 \
        rockchip_defconfig
    make -j"$JOBS" ARCH=arm64 \
        Image dtbs modules

    echo "==> Kernel build complete."
}

# =============================================================================
# AOSP - Full Android 16 build
# =============================================================================
# Runs the complete AOSP build producing all flashable images.
#
# Output images (in out/target/product/x88pro/):
#   boot.img       - Kernel + ramdisk
#   system.img     - Android framework
#   vendor.img     - Hardware drivers
#   product.img    - OEM customizations
#   super.img      - Combined dynamic partition image
#   recovery.img   - Recovery OS
#
# Expected final output:
#   #### build completed successfully (Xh Xm Xs) ####
aosp() {
    AOSP_DIR="${2}"
    PRODUCT="${3}"
    JOBS="${4:-$(nproc)}"

    echo "==> Starting full AOSP build..."
    echo "    Product: $PRODUCT"
    echo "    Jobs:    $JOBS"
    echo "    This will take several hours. Consider running in screen/tmux."
    echo ""

    cd "$AOSP_DIR"
    source build/envsetup.sh
    lunch "${PRODUCT}-userdebug"

    # m = build everything defined by the lunch target
    # -j = parallel jobs
    # showcommands = verbose output (remove for cleaner logs)
    m -j"$JOBS"

    echo ""
    echo "==> AOSP build complete!"
    echo "    Images are in: $AOSP_DIR/out/target/product/x88pro/"
    ls -lh "$AOSP_DIR/out/target/product/x88pro/"*.img 2>/dev/null || true
}

# --- Main --------------------------------------------------------------------
case "$COMMAND" in
    setup)  setup "$@" ;;
    kernel) kernel "$@" ;;
    aosp)   aosp "$@" ;;
    *)
        echo "Usage: $0 {setup|kernel|aosp}"
        exit 1
        ;;
esac
