#!/bin/bash
# =============================================================================
# X88 Pro RK3566 - Phase 2: Build Environment Setup
# =============================================================================
# Sets up Ubuntu 24.04 LTS for building Android 16.
# Run this on your Ubuntu build machine (NOT on Windows/WSL).
#
# Recommended machine specs (based on tested build machine):
#   - Ubuntu 24.04.4 LTS
#   - 32GB RAM
#   - 12+ CPU cores
#   - 584GB+ free disk space (NVMe recommended)
#
# Usage:
#   chmod +x phase2_environment.sh
#   ./phase2_environment.sh          - Run full Phase 2 setup (recommended)
#   ./phase2_environment.sh deps     - Install build dependencies only
#   ./phase2_environment.sh java     - Fix Java version only
#   ./phase2_environment.sh ccache   - Set up compiler cache only
#   ./phase2_environment.sh repo     - Install repo tool only
#   ./phase2_environment.sh sync     - Sync AOSP source only
#
# Full run order: deps -> java -> ccache -> repo -> sync
# Total time: several hours (dominated by ~100GB AOSP download)
# =============================================================================

set -e  # Exit immediately on any error

# --- Configuration -----------------------------------------------------------

AOSP_DIR="aosp"                          # AOSP source directory (relative to script)
AOSP_MANIFEST="https://android.googlesource.com/platform/manifest"
AOSP_BRANCH="android-16.0.0_r1"         # Android 16 stable release
CCACHE_SIZE="50G"                        # Compiler cache size (50GB is comfortable)
JAVA_VERSION="17"                        # AOSP Android 16 requires exactly Java 17

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info()    { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗ ERROR:${NC} $1"; exit 1; }

# =============================================================================
# DEPS - Install all required Ubuntu packages
# =============================================================================
# Installs everything needed to build AOSP Android 16 on Ubuntu 24.04.
#
# Key packages and why we need them:
#   git                       - Source control (repo uses git internally)
#   openjdk-17-jdk            - AOSP requires exactly Java 17 (not 21, not 11)
#   gcc-aarch64-linux-gnu     - ARM64 cross-compiler for building the kernel
#   device-tree-compiler      - dtc: converts binary DTB <-> text DTS (Phase 3)
#   android-sdk-libsparse-utils - simg2img: extracts super.img contents (Phase 3)
#   ccache                    - Compiler cache: makes rebuilds 2-5x faster
#   screen                    - Terminal multiplexer: keeps sync alive if SSH drops
#   flex/bison                - Parser generators used by the build system
#   lib32z1-dev/libc6-dev-i386 - 32-bit libs needed for some AOSP host tools
#
# Note on Ubuntu 24.04 changes vs older guides:
#   - libncurses5 was renamed to libncurses-dev
#   - git-core is now just 'git'
#   - Java 21 may be pre-installed but AOSP needs 17 (handled in java_setup())
#
# Expected output:
#   Reading package lists... Done
#   ...lots of package installation output...
#   Setting up openjdk-17-jdk:amd64 (17.0.x+x) ...
#   ==> Dependencies installed successfully.
#   ✓ git: git version 2.43.0
#   ✓ Java: openjdk version "17.0.x"  <- must be 17, not 21!
#   ✓ dtc: Version: DTC 1.7.0
#   ✓ aarch64-gcc: aarch64-linux-gnu-gcc (Ubuntu 13.x) 13.x.x
#   ✓ Python: Python 3.12.x
#   ✓ screen: Screen version 4.x.x
#
# Time: 5-15 minutes depending on internet speed
deps() {
    info "Installing AOSP build dependencies..."
    info "Updating package lists..."
    sudo apt-get update

    info "Installing packages (this may take a few minutes)..."
    sudo apt-get install -y \
        git \
        gnupg \
        flex \
        bison \
        build-essential \
        zip \
        curl \
        zlib1g-dev \
        libc6-dev-i386 \
        libncurses-dev \
        x11proto-core-dev \
        libx11-dev \
        lib32z1-dev \
        libgl1-mesa-dev \
        libxml2-utils \
        xsltproc \
        unzip \
        fontconfig \
        python3 \
        python3-pip \
        openjdk-17-jdk \
        bc \
        rsync \
        ccache \
        screen \
        device-tree-compiler \
        android-sdk-libsparse-utils \
        lzop \
        libssl-dev \
        libelf-dev \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
	binwalk \
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

    echo ""
    success "Dependencies installed successfully."
    success "git: $(git --version)"
    success "Java: $(java -version 2>&1 | head -1)"
    success "dtc: $(dtc --version)"
    success "aarch64-gcc: $(aarch64-linux-gnu-gcc --version | head -1)"
    success "Python: $(python3 --version)"
    success "screen: $(screen --version | head -1)"
    echo ""
}

# =============================================================================
# JAVA - Ensure Java 17 is the active version
# =============================================================================
# AOSP Android 16 requires exactly Java 17.
# Ubuntu 24.04 may have Java 21 pre-installed which takes priority.
# This function detects the situation and fixes it automatically.
#
# Expected output (if Java 21 was active):
#   ==> Checking Java version...
#   ⚠ Java 21 is active but AOSP requires Java 17. Switching...
#   ✓ Java 17 is now active: openjdk version "17.0.18" 2026-01-20
#
# Expected output (if Java 17 was already active):
#   ==> Checking Java version...
#   ✓ Java 17 is already active.
java_setup() {
    info "Checking Java version..."

    CURRENT_JAVA=$(java -version 2>&1 | head -1 | awk -F'"' '{print $2}' | cut -d'.' -f1)

    if [ "$CURRENT_JAVA" = "$JAVA_VERSION" ]; then
        success "Java $JAVA_VERSION is already active."
    else
        warning "Java $CURRENT_JAVA is active but AOSP requires Java $JAVA_VERSION. Switching..."

        # Check if Java 17 is installed
        if ! update-java-alternatives --list 2>/dev/null | grep -q "java-1.17"; then
            info "Java 17 not found, installing..."
            sudo apt-get install -y openjdk-17-jdk
        fi

        # Switch to Java 17 automatically (no interactive menu)
        sudo update-alternatives --set java \
            /usr/lib/jvm/java-17-openjdk-amd64/bin/java
        sudo update-alternatives --set javac \
            /usr/lib/jvm/java-17-openjdk-amd64/bin/javac

        ACTIVE=$(java -version 2>&1 | head -1)
        success "Java 17 is now active: $ACTIVE"
    fi

    # Verify it's really 17
    VERIFY=$(java -version 2>&1 | head -1 | awk -F'"' '{print $2}' | cut -d'.' -f1)
    [ "$VERIFY" = "17" ] || error "Java version is still not 17. Please run: sudo update-alternatives --config java"
    echo ""
}

# =============================================================================
# CCACHE - Set up compiler cache
# =============================================================================
# ccache caches the output of C/C++ compilations.
# First build: no speedup (cache is cold).
# Subsequent builds: 2-5x faster (only recompiles changed files).
#
# With 12 cores building Android 16:
#   Without ccache: ~4-6 hours per full build
#   With ccache:    ~30 min for incremental rebuilds after first build
#
# Expected output:
#   ==> Setting up ccache (compiler cache)...
#   Set cache size limit to 50.0 GB
#   ✓ ccache configured: max cache size  50.0 GB
#   ✓ ccache environment variables added to ~/.bashrc
setup_ccache() {
    info "Setting up ccache (compiler cache)..."

    mkdir -p "$HOME/.ccache"
    export CCACHE_DIR="$HOME/.ccache"
    ccache -M "$CCACHE_SIZE"

    # Add to bashrc only if not already there
    if ! grep -q "USE_CCACHE" ~/.bashrc; then
        echo 'export USE_CCACHE=1' >> ~/.bashrc
        echo 'export CCACHE_EXEC=$(which ccache)' >> ~/.bashrc
        echo 'export CCACHE_DIR=$HOME/.ccache' >> ~/.bashrc
        success "ccache environment variables added to ~/.bashrc"
    else
        success "ccache environment variables already in ~/.bashrc"
    fi

    export USE_CCACHE=1
    export CCACHE_EXEC=$(which ccache)

    CACHE_SIZE=$(ccache -s | grep "max cache size" | awk '{print $4, $5}')
    success "ccache configured: max cache size $CACHE_SIZE"
    echo ""
}

# =============================================================================
# REPO - Install Google's repo tool and configure git
# =============================================================================
# repo is Google's tool for managing the hundreds of git repositories
# that together make up AOSP. It reads a manifest XML file and clones/syncs
# all repos to the right places automatically.
#
# Expected output:
#   ==> Installing repo tool...
#   ✓ repo installed: repo launcher version 2.54
#   ==> Configuring git identity (required by repo)...
#   Enter your name for git commits: John Doe
#   Enter your email for git commits: john@example.com
#   ✓ Git configured for: John Doe <john@example.com>
repo_install() {
    info "Installing repo tool..."

    mkdir -p ~/bin
    curl -s https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
    chmod a+x ~/bin/repo

    # Add ~/bin to PATH if not already there
    if ! grep -q 'HOME/bin' ~/.bashrc; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="$HOME/bin:$PATH"

    success "repo installed: $(repo --version 2>&1 | grep 'repo launcher')"
    echo ""

    # Configure git identity (repo requires this before init)
    info "Configuring git identity (required by repo)..."

    # Check if already configured
    EXISTING_NAME=$(git config --global user.name 2>/dev/null || true)
    EXISTING_EMAIL=$(git config --global user.email 2>/dev/null || true)

    if [ -n "$EXISTING_NAME" ] && [ -n "$EXISTING_EMAIL" ]; then
        success "Git already configured for: $EXISTING_NAME <$EXISTING_EMAIL>"
        read -p "    Keep this identity? [Y/n] " keep
        [ "${keep:-Y}" = "n" ] || { echo ""; return; }
    fi

    read -p "    Enter your name for git commits: " GIT_NAME
    read -p "    Enter your email for git commits: " GIT_EMAIL
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global color.ui true
    success "Git configured for: $GIT_NAME <$GIT_EMAIL>"
    echo ""
}

# =============================================================================
# SYNC - Initialize repo and sync AOSP source
# =============================================================================
# Downloads the full Android 16 source tree (~100GB).
#
# Strategy:
#   1. Try fast sync with 16 parallel jobs first
#   2. If Google rate-limits us (HTTP 429 / RESOURCE_EXHAUSTED), automatically
#      retry with 4 jobs (gentler on Google's servers)
#   3. If that also fails, retry with 1 job as last resort
#
# This handles the common situation where Google throttles large parallel
# downloads after ~90GB - exactly what happened on our first sync attempt.
#
# Flags explained:
#   --depth=1        Shallow clone - saves significant disk space
#   --force-sync     Overwrite any local inconsistencies
#   --no-clone-bundle Faster for most connections (skips bundle optimization)
#   --no-tags        Skip tag downloads - saves time and space
#
# Expected output (success):
#   Fetching: 100% (xxx/xxx), done in xxxs
#   Updating files: 100% (xxx/xxx), done.
#   Syncing work tree: 100% (xxx/xxx), done.
#   ✓ AOSP sync complete! Source size: ~120G
#
# Expected output (rate limited then recovered):
#   ⚠ Sync with 16 jobs was rate-limited by Google. Retrying with 4 jobs...
#   Fetching: 100% (xxx/xxx), done in xxxs
#   ✓ AOSP sync complete! Source size: ~120G
#
# Time: 30 minutes to several hours depending on connection speed
# Disk: ~120GB after sync
sync() {
    # Resolve AOSP dir relative to the script's parent (project root)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    FULL_AOSP_DIR="$PROJECT_DIR/$AOSP_DIR"
    LOG_FILE="$PROJECT_DIR/sync.log"

    info "Initializing AOSP sync..."
    info "  Directory: $FULL_AOSP_DIR"
    info "  Manifest:  $AOSP_MANIFEST"
    info "  Branch:    $AOSP_BRANCH"
    echo ""
    warning "This will download ~100GB and take several hours."
    warning "It is strongly recommended to run this inside a screen session:"
    warning "  screen -S aosp-sync"
    warning "  ./phase2_environment.sh sync"
    warning "Detach with Ctrl+A then D. Reattach with: screen -r aosp-sync"
    echo ""
    read -p "Continue? [y/N] " confirm
    [ "${confirm}" = "y" ] || { echo "Aborted."; exit 0; }

    mkdir -p "$FULL_AOSP_DIR"
    cd "$FULL_AOSP_DIR"

    # Initialize repo manifest
    info "Initializing repo manifest..."
    repo init \
        --depth=1 \
        -u "$AOSP_MANIFEST" \
        -b "$AOSP_BRANCH"
    success "Repo initialized."
    echo ""

    # --- Sync with automatic fallback on rate limiting ---

    # Attempt 1: Fast sync with 16 parallel jobs
    info "Starting AOSP sync with 16 parallel jobs..."
    info "Output is also being saved to: $LOG_FILE"
    echo ""

    if repo sync -j16 --force-sync --no-clone-bundle --no-tags 2>&1 | tee "$LOG_FILE"; then
        echo ""
        success "AOSP sync complete! Source size: $(du -sh . | cut -f1)"
        echo ""
        return 0
    fi

    # Check if failure was due to rate limiting
    if grep -q "RESOURCE_EXHAUSTED\|HTTP 429\|429" "$LOG_FILE"; then
        echo ""
        warning "Sync with 16 jobs was rate-limited by Google. Retrying with 4 jobs..."
        warning "This is normal after large downloads. The remaining repos are few."
        echo ""
        sleep 10  # Brief pause before retry

        # Attempt 2: Gentler sync with 4 parallel jobs
        if repo sync -j4 --force-sync --no-clone-bundle --no-tags 2>&1 | tee -a "$LOG_FILE"; then
            echo ""
            success "AOSP sync complete! Source size: $(du -sh . | cut -f1)"
            echo ""
            return 0
        fi

        # Check if still rate limited
        if grep -q "RESOURCE_EXHAUSTED\|HTTP 429\|429" "$LOG_FILE"; then
            echo ""
            warning "Still rate-limited. Retrying with 1 job as last resort..."
            sleep 30  # Longer pause to let rate limit cool down

            # Attempt 3: Single job - slowest but most reliable
            if repo sync -j1 --force-sync --no-clone-bundle --no-tags 2>&1 | tee -a "$LOG_FILE"; then
                echo ""
                success "AOSP sync complete! Source size: $(du -sh . | cut -f1)"
                echo ""
                return 0
            fi
        fi
    fi

    # If we get here, sync failed for a non-rate-limit reason
    error "AOSP sync failed. Check $LOG_FILE for details."
}

# =============================================================================
# VERIFY - Verify Phase 2 is complete
# =============================================================================
# Checks that all tools are installed and AOSP source is present.
#
# Expected output (all good):
#   ==> Verifying Phase 2 setup...
#   ✓ git: git version 2.43.0
#   ✓ Java 17: openjdk version "17.0.18" 2026-01-20
#   ✓ dtc: Version: DTC 1.7.0
#   ✓ aarch64-gcc: aarch64-linux-gnu-gcc 13.x.x
#   ✓ ccache: 50.0 GB configured
#   ✓ repo: repo launcher version 2.54
#   ✓ AOSP source: present (~120G)
#   ✓ AOSP envsetup.sh: found
#   ✓ Phase 2 is complete! Ready for Phase 3.
verify() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    FULL_AOSP_DIR="$PROJECT_DIR/$AOSP_DIR"

    info "Verifying Phase 2 setup..."
    echo ""

    ERRORS=0

    # Check each tool
    check_tool() {
        local name="$1"
        local cmd="$2"
        local result
        result=$(eval "$cmd" 2>&1 | head -1)
        if [ $? -eq 0 ] && [ -n "$result" ]; then
            success "$name: $result"
        else
            echo -e "${RED}✗${NC} $name: NOT FOUND"
            ERRORS=$((ERRORS + 1))
        fi
    }

    check_tool "git" "git --version"
    check_tool "Java 17" "java -version 2>&1 | head -1"
    check_tool "dtc" "dtc --version"
    check_tool "aarch64-gcc" "aarch64-linux-gnu-gcc --version | head -1"
    check_tool "screen" "screen --version | head -1"
    check_tool "repo" "repo --version 2>&1 | grep 'repo launcher'"

    # Check Java is actually 17
    JAVA_VER=$(java -version 2>&1 | head -1 | awk -F'"' '{print $2}' | cut -d'.' -f1)
    if [ "$JAVA_VER" != "17" ]; then
        echo -e "${RED}✗${NC} Java version is $JAVA_VER, needs to be 17! Run: ./phase2_environment.sh java"
        ERRORS=$((ERRORS + 1))
    fi

    # Check ccache
    CACHE_SIZE=$(ccache -s 2>/dev/null | grep "Cache size (GB)" | awk '{print $4}')
    if [ -n "$CACHE_SIZE" ]; then
        success "ccache: $CACHE_SIZE configured"
    else
        echo -e "${RED}✗${NC} ccache not configured"
        ERRORS=$((ERRORS + 1))
    fi

    # Check AOSP source
    if [ -d "$FULL_AOSP_DIR/build" ]; then
        AOSP_SIZE=$(du -sh "$FULL_AOSP_DIR" 2>/dev/null | cut -f1)
        success "AOSP source: present (~$AOSP_SIZE)"
    else
        echo -e "${RED}✗${NC} AOSP source not found at $FULL_AOSP_DIR"
        ERRORS=$((ERRORS + 1))
    fi

    # Check envsetup.sh
    if [ -f "$FULL_AOSP_DIR/build/envsetup.sh" ]; then
        success "AOSP envsetup.sh: found"
    else
        echo -e "${RED}✗${NC} AOSP envsetup.sh not found - sync may be incomplete"
        ERRORS=$((ERRORS + 1))
    fi

    echo ""
    if [ $ERRORS -eq 0 ]; then
        success "Phase 2 is complete! Ready for Phase 3."
        echo ""
        echo "    Next steps:"
        echo "    1. Transfer backup/ folder from Windows to this machine"
        echo "    2. Run: make phase3"
    else
        echo -e "${RED}Phase 2 has $ERRORS issue(s). Fix them before proceeding.${NC}"
        exit 1
    fi
    echo ""
}

# =============================================================================
# FULL - Run all steps in sequence (default when no argument given)
# =============================================================================
full() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE} X88 Pro RK3566 - Phase 2: Full Setup${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    warning "This will install packages, configure tools, and sync ~100GB of AOSP source."
    warning "Ensure you have 250GB+ free disk space before continuing."
    echo ""
    read -p "Start full Phase 2 setup? [y/N] " confirm
    [ "${confirm}" = "y" ] || { echo "Aborted."; exit 0; }
    echo ""

    deps
    java_setup
    setup_ccache
    repo_install
    sync
    verify

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN} Phase 2 Complete!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo " Transfer your backup/ folder from Windows then run:"
    echo "   make phase3"
    echo ""
}

# --- Main --------------------------------------------------------------------
COMMAND="${1:-full}"

case "$COMMAND" in
    full)    full ;;
    deps)    deps ;;
    java)    java_setup ;;
    ccache)  setup_ccache ;;
    repo)    repo_install ;;
    sync)    sync ;;
    verify)  verify ;;
    *)
        echo "Usage: $0 {full|deps|java|ccache|repo|sync|verify}"
        echo ""
        echo "  (no argument)  Run full Phase 2 setup"
        echo "  deps           Install Ubuntu build packages"
        echo "  java           Fix Java version to 17"
        echo "  ccache         Set up compiler cache"
        echo "  repo           Install repo tool + configure git"
        echo "  sync           Sync AOSP source (~100GB)"
        echo "  verify         Verify Phase 2 is complete"
        exit 1
        ;;
esac
