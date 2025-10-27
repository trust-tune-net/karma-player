#!/bin/bash
# Bundle transmission-daemon for all platforms
# This script downloads and prepares transmission binaries for packaging

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUNDLE_DIR="$PROJECT_ROOT/transmission-binaries"

# Transmission versions
TRANSMISSION_VERSION="4.0.5"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}🔧 Bundling Transmission Daemon for TrustTune${RESET}"
echo ""

# Create bundle directory
mkdir -p "$BUNDLE_DIR"/{macos,windows,linux}

# Function to download with progress
download_file() {
    local url=$1
    local output=$2
    echo -e "${YELLOW}📥 Downloading: $url${RESET}"
    curl -L --progress-bar -o "$output" "$url"
}

# ============================================================================
# macOS Binary
# ============================================================================
echo -e "${GREEN}🍎 Preparing macOS binary...${RESET}"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # On macOS, check if transmission is installed via Homebrew
    if command -v transmission-daemon &> /dev/null; then
        TRANS_PATH=$(which transmission-daemon)
        echo -e "${GREEN}✅ Found transmission-daemon at: $TRANS_PATH${RESET}"

        # Copy the binary
        cp "$TRANS_PATH" "$BUNDLE_DIR/macos/transmission-daemon"

        # Copy required dylibs
        echo -e "${YELLOW}📦 Bundling dependencies...${RESET}"
        mkdir -p "$BUNDLE_DIR/macos/lib"

        # Get all dylib dependencies
        DYLIBS=$(otool -L "$TRANS_PATH" | grep -v '/usr/lib' | grep -v '/System' | awk '{print $1}' | tail -n +2)

        for dylib in $DYLIBS; do
            if [ -f "$dylib" ]; then
                DYLIB_NAME=$(basename "$dylib")
                cp "$dylib" "$BUNDLE_DIR/macos/lib/$DYLIB_NAME"
                echo "  ├─ $DYLIB_NAME"
            fi
        done

        # Update library paths to be relative (use @loader_path, not @executable_path)
        chmod +w "$BUNDLE_DIR/macos/transmission-daemon"
        for dylib in $BUNDLE_DIR/macos/lib/*; do
            DYLIB_NAME=$(basename "$dylib")
            # Use @loader_path which is relative to the binary location, not the main executable
            install_name_tool -change "/opt/homebrew/opt/*/lib/$DYLIB_NAME" "@loader_path/../lib/$DYLIB_NAME" "$BUNDLE_DIR/macos/transmission-daemon" 2>/dev/null || true
            install_name_tool -change "/usr/local/opt/*/lib/$DYLIB_NAME" "@loader_path/../lib/$DYLIB_NAME" "$BUNDLE_DIR/macos/transmission-daemon" 2>/dev/null || true
        done

        # Re-sign binary after modifying it
        echo -e "${YELLOW}🔏 Signing binary...${RESET}"
        codesign --force --sign - "$BUNDLE_DIR/macos/transmission-daemon"

        echo -e "${GREEN}✅ macOS binary prepared${RESET}"
    else
        echo -e "${RED}❌ transmission-daemon not found on macOS${RESET}"
        echo -e "${YELLOW}Install with: brew install transmission${RESET}"
        exit 1
    fi
else
    echo -e "${YELLOW}⏩ Skipping macOS binary (not on macOS)${RESET}"
fi

echo ""

# ============================================================================
# Windows Binary
# ============================================================================
echo -e "${GREEN}🪟 Preparing Windows binary...${RESET}"

# Download official Transmission Windows build
WINDOWS_URL="https://github.com/transmission/transmission/releases/download/${TRANSMISSION_VERSION}/transmission-${TRANSMISSION_VERSION}-x64.msi"

echo -e "${YELLOW}Note: Windows binary needs to be extracted manually from MSI${RESET}"
echo -e "${YELLOW}Download from: $WINDOWS_URL${RESET}"
echo -e "${YELLOW}Extract transmission-daemon.exe to: $BUNDLE_DIR/windows/${RESET}"
echo ""

# ============================================================================
# Linux Binary
# ============================================================================
echo -e "${GREEN}🐧 Preparing Linux binary...${RESET}"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # On Linux, check if transmission-daemon is installed
    if command -v transmission-daemon &> /dev/null; then
        TRANS_PATH=$(which transmission-daemon)
        echo -e "${GREEN}✅ Found transmission-daemon at: $TRANS_PATH${RESET}"

        # Copy the binary
        cp "$TRANS_PATH" "$BUNDLE_DIR/linux/transmission-daemon"

        # Linux binary is typically dynamically linked to system libraries
        # We'll document which libraries are required
        ldd "$TRANS_PATH" > "$BUNDLE_DIR/linux/DEPENDENCIES.txt"

        echo -e "${GREEN}✅ Linux binary prepared${RESET}"
        echo -e "${YELLOW}📝 Dependencies documented in DEPENDENCIES.txt${RESET}"
    else
        echo -e "${YELLOW}⚠️  transmission-daemon not found on Linux${RESET}"
        echo -e "${YELLOW}Install with: sudo apt install transmission-daemon${RESET}"
    fi
else
    echo -e "${YELLOW}⏩ Skipping Linux binary (not on Linux)${RESET}"
fi

echo ""

# ============================================================================
# Create README for binaries
# ============================================================================
cat > "$BUNDLE_DIR/README.md" << 'EOF'
# Transmission Binaries for TrustTune

This directory contains platform-specific transmission-daemon binaries to be bundled with TrustTune.

## Directory Structure

```
transmission-binaries/
├── macos/
│   ├── transmission-daemon (binary)
│   └── lib/ (dylib dependencies)
├── windows/
│   └── transmission-daemon.exe
└── linux/
    └── transmission-daemon
```

## Building

### macOS
Run `./scripts/bundle-transmission.sh` on macOS with Homebrew transmission installed.

### Windows
1. Download Transmission MSI from: https://github.com/transmission/transmission/releases
2. Extract `transmission-daemon.exe`
3. Place in `windows/` directory

### Linux
Run `./scripts/bundle-transmission.sh` on Linux with transmission-daemon installed.

## Integration

The Flutter app expects binaries at:
- **macOS**: `Contents/Resources/bin/transmission-daemon`
- **Windows**: `transmission-daemon.exe` (next to app executable)
- **Linux**: `bin/transmission-daemon` (in app directory)

Build scripts copy from this directory to the appropriate locations.
EOF

echo -e "${GREEN}✅ README created at: $BUNDLE_DIR/README.md${RESET}"
echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════${RESET}"
echo -e "${GREEN}✅ Transmission bundling preparation complete!${RESET}"
echo -e "${BLUE}═══════════════════════════════════════════════${RESET}"
echo ""
echo "Binaries prepared in: $BUNDLE_DIR"
echo ""
echo "Next steps:"
echo "1. Run this script on each platform (macOS, Windows, Linux)"
echo "2. Commit the binaries to the repo (or download in CI)"
echo "3. Update GitHub Actions to copy binaries during build"
echo ""
