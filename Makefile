# =============================================================================
# X88 Pro RK3566 - Android 16 Build System
# =============================================================================
#
# This Makefile orchestrates all phases of building Android 16
# for the X88 Pro RK3566 Android TV box.
#
# Usage:
#   make help                  - Show this help
#   make phase1                - Extract data from device (run on Windows/WSL)
#   make phase2                - Set up build environment  (run on Ubuntu)
#   make phase3                - Prepare device tree and vendor blobs
#   make phase4                - Build Android 16
#   make phase5                - Flash to device
#   make all                   - Run phases 2-4 in sequence (build only)
#
# Prerequisites:
#   - Ubuntu 24.04 LTS build machine (16GB+ RAM, 250GB+ disk)
#   - X88 Pro box with ADB over network enabled
#   - See README.md for full setup instructions
#
# Authors: Community project - contributions welcome!
# Device:  X88 Pro (X88PRO-RK3566-4D32-V1.0)
# SoC:     Rockchip RK3566 (4x Cortex-A55, Mali-G52)
# RAM:     8GB LPDDR4
# Storage: 128GB eMMC
# =============================================================================

# --- Configuration -----------------------------------------------------------

DEVICE        := x88pro
VENDOR        := rockchip
PRODUCT       := $(VENDOR)_$(DEVICE)
ANDROID_VER   := 16
BOX_IP        ?= 192.168.1.105       # Override with: make phase1 BOX_IP=x.x.x.x
BACKUP_DIR    := backup
OUT_DIR       := out
JOBS          ?= $(shell nproc)      # Use all available CPU cores for building

# Rockchip Android 16 source (community fork targeting RK3566)
AOSP_MANIFEST := https://github.com/rockchip-linux/manifests
AOSP_BRANCH   := android-16-rk356x  # Target branch (to be confirmed/created)
AOSP_DIR      := aosp

# Colors for terminal output
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
NC     := \033[0m  # No Color

# =============================================================================
# PHONY TARGETS
# =============================================================================
.PHONY: all help \
        phase1 phase1-connect phase1-extract phase1-backup \
        phase2 phase2-deps phase2-repo phase2-sync \
        phase3 phase3-extract-dt phase3-extract-blobs phase3-device-tree \
        phase4 phase4-setup phase4-kernel phase4-aosp \
        phase5 phase5-flash phase5-verify \
        clean mrproper status

# =============================================================================
# DEFAULT TARGET
# =============================================================================
all: phase2 phase3 phase4
	@echo -e "$(GREEN)Full build complete! Run 'make phase5' to flash.$(NC)"

# =============================================================================
# HELP
# =============================================================================
help:
	@echo ""
	@echo -e "$(BLUE)X88 Pro RK3566 - Android 16 Build System$(NC)"
	@echo "=========================================="
	@echo ""
	@echo "PHASES:"
	@echo ""
	@echo -e "  $(YELLOW)Phase 1 - Device Extraction$(NC) (Windows/WSL with ADB)"
	@echo "    make phase1              - Run full extraction"
	@echo "    make phase1-connect      - Connect ADB to box"
	@echo "    make phase1-extract      - Pull all partition images"
	@echo "    make phase1-backup       - Verify and backup extracted files"
	@echo "    BOX_IP=x.x.x.x make phase1  - Specify box IP address"
	@echo ""
	@echo -e "  $(YELLOW)Phase 2 - Build Environment$(NC) (Ubuntu 24.04)"
	@echo "    make phase2              - Full environment setup"
	@echo "    make phase2-deps         - Install build dependencies"
	@echo "    make phase2-repo         - Install repo tool"
	@echo "    make phase2-sync         - Sync AOSP source (~100GB)"
	@echo ""
	@echo -e "  $(YELLOW)Phase 3 - Device Preparation$(NC)"
	@echo "    make phase3              - Full device preparation"
	@echo "    make phase3-extract-dt   - Convert DTB to DTS source"
	@echo "    make phase3-extract-blobs - Extract vendor blobs from super.img"
	@echo "    make phase3-device-tree  - Generate device tree for Android 16"
	@echo ""
	@echo -e "  $(YELLOW)Phase 4 - Build$(NC)"
	@echo "    make phase4              - Full Android 16 build"
	@echo "    make phase4-setup        - Configure build environment"
	@echo "    make phase4-kernel       - Build kernel only"
	@echo "    make phase4-aosp         - Build AOSP (after kernel)"
	@echo ""
	@echo -e "  $(YELLOW)Phase 5 - Flash$(NC)"
	@echo "    make phase5              - Flash all partitions to device"
	@echo "    make phase5-flash        - Flash images"
	@echo "    make phase5-verify       - Verify flash success"
	@echo ""
	@echo "UTILITIES:"
	@echo "    make status              - Show current phase completion status"
	@echo "    make clean               - Clean build output"
	@echo "    make mrproper            - Clean everything including AOSP"
	@echo ""
	@echo "CONFIGURATION:"
	@echo "    BOX_IP=$(BOX_IP)   (default box IP)"
	@echo "    JOBS=$(JOBS)                    (parallel build jobs)"
	@echo ""

# =============================================================================
# PHASE 1 - DEVICE EXTRACTION
# =============================================================================
# Run this phase on your Windows/WSL machine with the box on the same network.
# Extracts all partition images and device tree from the running Android 11 box.
# These files are essential for phases 3, 4 and 5.
# =============================================================================

phase1: phase1-connect phase1-extract phase1-backup
	@echo -e "$(GREEN)Phase 1 complete! Copy $(BACKUP_DIR)/ to your Ubuntu build machine.$(NC)"

phase1-connect:
	@echo -e "$(BLUE)==> Phase 1: Connecting to box at $(BOX_IP)...$(NC)"
	@scripts/phase1_extraction.sh connect $(BOX_IP)

phase1-extract:
	@echo -e "$(BLUE)==> Phase 1: Extracting partitions and device tree...$(NC)"
	@scripts/phase1_extraction.sh extract $(BOX_IP) $(BACKUP_DIR)

phase1-backup:
	@echo -e "$(BLUE)==> Phase 1: Verifying backup...$(NC)"
	@scripts/phase1_extraction.sh verify $(BACKUP_DIR)

# =============================================================================
# PHASE 2 - BUILD ENVIRONMENT SETUP                              [✅ COMPLETE]
# =============================================================================
# Completed: Ubuntu 24.04.4 LTS, Java 17.0.18, ccache 50GB,
#            AOSP android-16.0.0_r1 synced (120GB on NVMe)
# =============================================================================
# Run this phase on your Ubuntu 24.04 build machine.
# Installs all required tools and syncs the AOSP + Rockchip source tree.
# Warning: AOSP sync downloads ~100GB of source code.
# =============================================================================
phase2: phase2-deps phase2-repo phase2-sync
	@echo -e "$(GREEN)Phase 2 complete! Build environment ready.$(NC)"

phase2-deps:
	@echo -e "$(BLUE)==> Phase 2: Installing build dependencies...$(NC)"
	@scripts/phase2_environment.sh deps

phase2-repo:
	@echo -e "$(BLUE)==> Phase 2: Installing repo tool...$(NC)"
	@scripts/phase2_environment.sh repo

phase2-sync:
	@echo -e "$(BLUE)==> Phase 2: Syncing AOSP source (~100GB, this will take hours)...$(NC)"
	@echo -e "$(YELLOW)    Tip: Run this overnight on a fast connection.$(NC)"
	@scripts/phase2_environment.sh sync $(AOSP_DIR) $(AOSP_MANIFEST) $(AOSP_BRANCH)

# =============================================================================
# PHASE 3 - DEVICE PREPARATION                                   [✅ COMPLETE]
# =============================================================================
# Converts our extracted device data into the format Android 16 needs.
#
# Hardware confirmed from Phase 1 (research-verified March 2026):
#   SoC:          Rockchip RK3566 (rk356x family)
#   RAM:          8GB LPDDR4
#   Storage:      128GB eMMC
#   Ethernet:     Synopsys GMAC (stmmac driver - mainline) ✅
#   WiFi/BT:      AMPAK AP6398S (BCM4359c0) - bcmdhd (out-of-tree) + btbcm 🔧
#   GPU:          Mali-G52 Bifrost - libGLES_mali.so blob (NOT Panfrost) 🔧
#   Video decode: RKVDEC2 - Rockchip MPP (BSP kernel, no mainline driver) 🔧
#   Video encode: RKVENC  - Rockchip MPP 🔧
#   NPU:          RKNPU   - open source kernel driver + RKNN2 SDK 🔧
#   HDMI audio:   PCM stereo only (no DD/DTS passthrough) ⚠️
#   AV1/HDR:      NOT supported by RK3566 hardware ❌
#
# Steps:
#   3a. extract-dt    - Convert binary DTB -> human-readable DTS source
#   3b. extract-blobs - Unpack vendor partition from super.img
#                       (libGLES_mali.so, libmpp.so, WiFi/BT firmware)
#   3c. npu-blobs     - Download RKNN2 runtime (replaces Android 11 NPU blobs)
#   3d. device-tree   - Generate Android 16 device tree skeleton
# =============================================================================

phase3: phase3-extract-dt phase3-extract-blobs phase3-npu-blobs phase3-device-tree
	@echo -e "$(GREEN)Phase 3 complete! Device tree and vendor blobs ready.$(NC)"

phase3-extract-dt:
	@echo -e "$(BLUE)==> Phase 3a: Converting device tree blob to source...$(NC)"
	@[ -f "$(BACKUP_DIR)/dtbo.img" ] || (echo -e "$(RED)ERROR: $(BACKUP_DIR)/dtbo.img not found. Run phase1 first.$(NC)" && exit 1)
	@scripts/phase3_device_prep.sh extract-dt $(BACKUP_DIR) device/$(VENDOR)/$(DEVICE)

phase3-extract-blobs:
	@echo -e "$(BLUE)==> Phase 3b: Extracting vendor blobs from super.img...$(NC)"
	@[ -f "$(BACKUP_DIR)/super.img" ] || (echo -e "$(RED)ERROR: $(BACKUP_DIR)/super.img not found. Run phase1 first.$(NC)" && exit 1)
	@echo -e "$(YELLOW)    Extracts: ALL vendor blobs (~1169 files) with auto-detection of WiFi/BT chip$(NC)"
	@echo -e "$(YELLOW)    Compatible with X88 Pro, H96 Max, and other RK3566 TV boxes$(NC)"
	@echo -e "$(YELLOW)    Note: NPU blobs intentionally skipped (Android 11 RKNN v1 incompatible with Android 16)$(NC)"
	@scripts/phase3_device_prep.sh extract-blobs $(BACKUP_DIR)/super.img device/$(VENDOR)/$(DEVICE)/proprietary

phase3-npu-blobs:
	@echo -e "$(BLUE)==> Phase 3c: Downloading RKNN2 NPU runtime from Rockchip SDK...$(NC)"
	@echo -e "$(YELLOW)    Using RKNN2 instead of Android 11 blobs - compatible with Android 16 HALs$(NC)"
	@scripts/phase3_device_prep.sh npu-blobs device/$(VENDOR)/$(DEVICE)/proprietary

phase3-device-tree:
	@echo -e "$(BLUE)==> Phase 3d: Generating Android 16 device tree...$(NC)"
	@scripts/phase3_device_prep.sh device-tree $(DEVICE) $(VENDOR) device/$(VENDOR)/$(DEVICE)

# =============================================================================
# PHASE 4 - BUILD ANDROID 16 [✅ COMPLETE]
# =============================================================================
# The actual AOSP build. This will take several hours even on fast hardware.
# Approximate build times:
#   - 8-core CPU, 32GB RAM, NVMe SSD:  ~3-4 hours
#   - 4-core CPU, 16GB RAM, SSD:       ~6-8 hours
#   - 4-core CPU, 16GB RAM, HDD:       ~10-12 hours
# =============================================================================

phase4: phase4-setup phase4-kernel phase4-aosp
	@echo -e "$(GREEN)Phase 4 complete! Android 16 images built successfully.$(NC)"
	@echo -e "$(GREEN)Images are in: $(AOSP_DIR)/out/target/product/$(DEVICE)/$(NC)"

phase4-setup:
	@echo -e "$(BLUE)==> Phase 4: Setting up build environment...$(NC)"
	@scripts/phase4_build.sh setup $(AOSP_DIR) $(PRODUCT)

phase4-kernel:
	@echo -e "$(BLUE)==> Phase 4: Building kernel (this takes ~30-60 min)...$(NC)"
	@scripts/phase4_build.sh kernel $(AOSP_DIR) $(JOBS)

phase4-aosp:
	@echo -e "$(BLUE)==> Phase 4: Building AOSP (this takes several hours)...$(NC)"
	@echo -e "$(YELLOW)    Jobs: $(JOBS) parallel processes$(NC)"
	@scripts/phase4_build.sh aosp $(AOSP_DIR) $(PRODUCT) $(JOBS)

# =============================================================================
# PHASE 5 - FLASH TO DEVICE [🔜 READY — install rkdeveloptool first]
# =============================================================================
# Flashes the built Android 16 images to the X88 Pro box.
# The box enters Rockchip loader mode for flashing (different from fastboot).
# Your original Android 11 backup from Phase 1 can restore the box if needed.
#
# WARNING: This will erase Android 11 from the box. Ensure you have a
#          working backup from Phase 1 before proceeding!
# =============================================================================

phase5: phase5-flash phase5-verify
	@echo -e "$(GREEN)Phase 5 complete! Android 16 is now on your X88 Pro!$(NC)"

phase5-flash:
	@echo -e "$(BLUE)==> Phase 5: Flashing Android 16 to X88 Pro...$(NC)"
	@echo -e "$(RED)WARNING: This will replace Android 11. Backup must exist at $(BACKUP_DIR)/$(NC)"
	@[ -f "$(BACKUP_DIR)/boot.img" ] || (echo -e "$(RED)ERROR: No backup found! Run phase1 first!$(NC)" && exit 1)
	@scripts/phase5_flash.sh flash $(AOSP_DIR) $(DEVICE) $(BOX_IP)

phase5-verify:
	@echo -e "$(BLUE)==> Phase 5: Verifying installation...$(NC)"
	@scripts/phase5_flash.sh verify $(BOX_IP)

# =============================================================================
# STATUS - Show which phases have been completed
# =============================================================================

status:
	@echo ""
	@echo -e "$(BLUE)X88 Pro Android 16 - Build Status$(NC)"
	@echo "=================================="
	@echo ""
	@# Phase 1
	@if [ -f "$(BACKUP_DIR)/super.img" ] && [ -f "$(BACKUP_DIR)/boot.img" ] && [ -d "$(BACKUP_DIR)/device-tree-backup" ]; then \
		echo -e "  Phase 1 (Extraction):    $(GREEN)COMPLETE$(NC)"; \
	elif [ -f "$(BACKUP_DIR)/boot.img" ]; then \
		echo -e "  Phase 1 (Extraction):    $(YELLOW)PARTIAL$(NC) (super.img missing)"; \
	else \
		echo -e "  Phase 1 (Extraction):    $(RED)NOT STARTED$(NC)"; \
	fi
	@# Phase 2
	@if [ -d "$(AOSP_DIR)/.repo" ] && [ -f "$(AOSP_DIR)/build/envsetup.sh" ]; then \
		echo -e "  Phase 2 (Environment):   $(GREEN)COMPLETE$(NC)"; \
	elif [ -d "$(AOSP_DIR)/.repo" ]; then \
		echo -e "  Phase 2 (Environment):   $(YELLOW)PARTIAL$(NC) (sync incomplete)"; \
	else \
		echo -e "  Phase 2 (Environment):   $(RED)NOT STARTED$(NC)"; \
	fi
	@# Phase 3
	@if [ -d "device/$(VENDOR)/$(DEVICE)/proprietary" ] && [ -f "device/$(VENDOR)/$(DEVICE)/device.mk" ]; then \
		echo -e "  Phase 3 (Device Prep):   $(GREEN)COMPLETE$(NC)"; \
	elif [ -f "device/$(VENDOR)/$(DEVICE)/device.mk" ]; then \
		echo -e "  Phase 3 (Device Prep):   $(YELLOW)PARTIAL$(NC) (blobs missing)"; \
	else \
		echo -e "  Phase 3 (Device Prep):   $(RED)NOT STARTED$(NC)"; \
	fi
	@# Phase 4
	@if [ -f "$(AOSP_DIR)/out/target/product/$(DEVICE)/boot.img" ]; then \
		echo -e "  Phase 4 (Build):         $(GREEN)COMPLETE$(NC)"; \
	elif [ -d "$(AOSP_DIR)/out" ]; then \
		echo -e "  Phase 4 (Build):         $(YELLOW)IN PROGRESS$(NC)"; \
	else \
		echo -e "  Phase 4 (Build):         $(RED)NOT STARTED$(NC)"; \
	fi
	@# Phase 5
	@if adb connect $(BOX_IP):5555 2>/dev/null | grep -q "connected" && \
	    adb shell getprop ro.build.version.release 2>/dev/null | grep -q "^16"; then \
		echo -e "  Phase 5 (Flash):         $(GREEN)COMPLETE - Android 16 running!$(NC)"; \
	else \
		echo -e "  Phase 5 (Flash):         $(RED)NOT STARTED$(NC)"; \
	fi
	@echo ""

# =============================================================================
# CLEAN TARGETS
# =============================================================================

clean:
	@echo -e "$(YELLOW)==> Cleaning build output...$(NC)"
	@rm -rf $(AOSP_DIR)/out
	@echo "Done. Source tree intact."

mrproper:
	@echo -e "$(RED)==> WARNING: This will delete the entire AOSP source tree!$(NC)"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@rm -rf $(AOSP_DIR) $(OUT_DIR)
	@echo "Done."
