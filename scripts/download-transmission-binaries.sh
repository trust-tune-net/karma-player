#!/bin/bash
# Download pre-built transmission binaries for CI/CD
# This script downloads binaries from official sources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUNDLE_DIR="$PROJECT_ROOT/transmission-binaries"

TRANSMISSION_VERSION="4.0.5"

echo "📦 Downloading Transmission binaries for CI/CD..."
mkdir -p "$BUNDLE_DIR"/{macos,windows,linux}

# ============================================================================
# macOS - Download from Homebrew bottles
# ============================================================================
download_macos() {
    echo "🍎 Downloading macOS binary..."

    # For macOS, we'll download the Homebrew bottle
    # Architecture detection
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        BOTTLE_ARCH="arm64_sonoma"
    else
        BOTTLE_ARCH="x86_64_monterey"
    fi

    # Download Homebrew bottle
    BOTTLE_URL="https://ghcr.io/v2/homebrew/core/transmission/blobs/sha256:HASH"

    echo "⚠️  Manual step required for macOS:"
    echo "   1. Install Homebrew transmission: brew install transmission"
    echo "   2. Run: cp \$(which transmission-daemon) $BUNDLE_DIR/macos/"
    echo "   3. Run: ./scripts/bundle-transmission.sh to bundle dependencies"
}

# ============================================================================
# Windows - Download from GitHub releases
# ============================================================================
download_windows() {
    echo "🪟 Downloading Windows binary..."

    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    # Download the portable ZIP version (easier than MSI)
    WINDOWS_URL="https://github.com/transmission/transmission/releases/download/${TRANSMISSION_VERSION}/transmission-${TRANSMISSION_VERSION}-x64.zip"

    if command -v wget &> /dev/null; then
        wget -q --show-progress "$WINDOWS_URL" -O transmission-windows.zip
    elif command -v curl &> /dev/null; then
        curl -L --progress-bar "$WINDOWS_URL" -o transmission-windows.zip
    else
        echo "❌ Error: Neither wget nor curl found"
        exit 1
    fi

    # Extract
    echo "📦 Extracting..."
    if command -v unzip &> /dev/null; then
        unzip -q transmission-windows.zip
    else
        echo "❌ Error: unzip not found"
        exit 1
    fi

    # Find and copy transmission-daemon.exe
    find . -name "transmission-daemon.exe" -exec cp {} "$BUNDLE_DIR/windows/" \;

    # Copy required DLLs
    find . -name "*.dll" -exec cp {} "$BUNDLE_DIR/windows/" \;

    # Cleanup
    cd "$PROJECT_ROOT"
    rm -rf "$TEMP_DIR"

    echo "✅ Windows binary downloaded"
}

# ============================================================================
# Linux - Build static binary or use AppImage
# ============================================================================
download_linux() {
    echo "🐧 Preparing Linux binary..."

    # For Linux, we need a static binary or bundle all dependencies
    # Option 1: Download AppImage and extract
    # Option 2: Build static binary
    # Option 3: Document system dependencies (current approach)

    echo "⚠️  Linux binary strategy:"
    echo "   Option 1: Rely on system transmission-daemon (document in README)"
    echo "   Option 2: Build static binary (complex)"
    echo "   Option 3: Bundle AppImage (large)"
    echo ""
    echo "Current approach: Option 1 (system package)"
    echo "Users install: sudo apt install transmission-daemon"

    # Create a stub script that checks for system transmission
    cat > "$BUNDLE_DIR/linux/transmission-daemon" << 'EOF'
#!/bin/bash
# Wrapper script for transmission-daemon on Linux
# Checks for system-installed transmission-daemon

if command -v transmission-daemon &> /dev/null; then
    exec transmission-daemon "$@"
else
    echo "Error: transmission-daemon not found"
    echo "Please install: sudo apt install transmission-daemon"
    exit 1
fi
EOF
    chmod +x "$BUNDLE_DIR/linux/transmission-daemon"

    echo "✅ Linux wrapper script created"
}

# ============================================================================
# Platform detection and download
# ============================================================================

case "$1" in
    macos)
        download_macos
        ;;
    windows)
        download_windows
        ;;
    linux)
        download_linux
        ;;
    all)
        download_macos
        download_windows
        download_linux
        ;;
    *)
        echo "Usage: $0 {macos|windows|linux|all}"
        exit 1
        ;;
esac

echo ""
echo "✅ Done! Binaries prepared in: $BUNDLE_DIR"
