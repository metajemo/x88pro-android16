#!/bin/bash
# =============================================================================
# X88 Pro RK3566 - Phase 2: Build Environment Setup
# =============================================================================
# Sets up Ubuntu 24.04 for building Android 16.
# Run on your Ubuntu build machine (not WSL).
#
# Usage:
#   ./phase2_environment.sh deps          - Install build dependencies
#   ./phase2_environment.sh repo          - Install repo tool
#   ./phase2_environment.sh sync DIR URL BRANCH - Sync AOSP source
# =============================================================================

set -e  # Exit on any error

COMMAND="${1}"

# =============================================================================
# DEPS - Install all required Ubuntu packages
# =============================================================================
# Expected: All packages install without errors
# Time: 5-15 minutes depending on internet speed
deps() {
    echo "==> Installing AOSP build dependencies..."
    sudo apt-get update
    sudo apt-get install -y \
        git-core \
        gnupg \
        flex \
        bison \
        build-essential \
        zip \
        curl \
        zlib1g-dev \
        libc6-dev-i386 \
        libncurses5 \
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
        device-tree-compiler \   # dtc - needed for Phase 3 (device tree conversion)
        android-sdk-libsparse-utils  # simg2img - needed for Phase 3 (super.img extraction)

    echo "==> Dependencies installed successfully."
    echo "    Java version: $(java -version 2>&1 | head -1)"
    echo "    Python version: $(python3 --version)"
    echo "    dtc version: $(dtc --version)"
}

# =============================================================================
# REPO - Install the repo tool
# =============================================================================
# repo is Google's tool for managing the many git repositories that make up AOSP.
# Expected output:
#   repo installed to ~/bin/repo
#   repo version: repo launcher version 2.x
repo_install() {
    echo "==> Installing repo tool..."
    mkdir -p ~/bin
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
    chmod a+x ~/bin/repo

    # Add ~/bin to PATH if not already there
    if ! echo "$PATH" | grep -q "$HOME/bin"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/bin:$PATH"
    fi

    echo "==> repo installed: $(repo --version 2>&1 | head -1)"

    # Configure git identity (required by repo)
    echo ""
    echo "==> Configuring git identity (required by repo)..."
    read -p "Enter your name for git commits: " GIT_NAME
    read -p "Enter your email for git commits: " GIT_EMAIL
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global color.ui true
    echo "==> Git configured for: $GIT_NAME <$GIT_EMAIL>"
}

# =============================================================================
# SYNC - Initialize and sync AOSP source
# =============================================================================
# Downloads the full Android 16 source tree with Rockchip RK3566 support.
# WARNING: This is ~100GB and will take several hours on a typical connection.
#
# Expected final output:
#   Syncing work tree: 100% (XXXX/XXXX), done.
#   repo sync complete.
sync() {
    AOSP_DIR="${2:-aosp}"
    MANIFEST_URL="${3}"
    BRANCH="${4}"

    echo "==> Syncing AOSP source to: $AOSP_DIR"
    echo "    Manifest: $MANIFEST_URL"
    echo "    Branch:   $BRANCH"
    echo ""
    echo "    This will download ~100GB and take several hours."
    echo "    Tip: Run inside a 'screen' or 'tmux' session so it"
    echo "         survives if your SSH connection drops."
    echo ""
    read -p "Continue? [y/N] " confirm
    [ "$confirm" = "y" ] || exit 0

    mkdir -p "$AOSP_DIR"
    cd "$AOSP_DIR"

    # Initialize repo with the Rockchip Android 16 manifest
    repo init \
        --depth=1 \
        -u "$MANIFEST_URL" \
        -b "$BRANCH"

    # Sync all repositories in parallel (16 jobs)
    # --force-sync: overwrite local changes if any
    # --no-clone-bundle: faster for some connections
    repo sync \
        -j16 \
        --force-sync \
        --no-clone-bundle \
        --no-tags

    echo ""
    echo "==> AOSP sync complete!"
    echo "    Source size: $(du -sh . | cut -f1)"
    echo "    Next: Run 'make phase3' to prepare device tree and vendor blobs."
}

# =============================================================================
# CCACHE - Set up compiler cache (optional but speeds up rebuilds significantly)
# =============================================================================
# ccache caches compiled object files so incremental builds are much faster.
# First build: no speedup. Subsequent builds: 2-5x faster.
#
# Expected output:
#   ccache configured with 50GB cache at ~/.ccache
setup_ccache() {
    echo "==> Setting up ccache (compiler cache)..."
    ccache -M 50G   # Set cache size to 50GB
    echo 'export USE_CCACHE=1' >> ~/.bashrc
    echo 'export CCACHE_EXEC=$(which ccache)' >> ~/.bashrc
    export USE_CCACHE=1
    export CCACHE_EXEC=$(which ccache)
    echo "==> ccache configured: $(ccache -s | grep 'max cache size')"
}

# --- Main --------------------------------------------------------------------
case "$COMMAND" in
    deps)   deps ;;
    repo)   repo_install ;;
    sync)   sync "$@" ;;
    ccache) setup_ccache ;;
    *)
        echo "Usage: $0 {deps|repo|sync|ccache}"
        echo ""
        echo "  deps          Install Ubuntu build packages"
        echo "  repo          Install repo tool"
        echo "  sync DIR URL BRANCH   Sync AOSP source"
        echo "  ccache        Set up compiler cache (recommended)"
        exit 1
        ;;
esac
