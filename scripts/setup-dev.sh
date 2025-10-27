#!/bin/bash
# Setup development environment with bundled Transmission
# Run this once after cloning the repo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔧 Setting up TrustTune development environment"
echo ""

# Step 1: Bundle Transmission
echo "📦 Step 1: Bundling Transmission..."
if [ ! -f "$PROJECT_ROOT/transmission-binaries/macos/transmission-daemon" ]; then
    echo "  Running bundle script..."
    "$SCRIPT_DIR/bundle-transmission.sh"
else
    echo "  ✅ Transmission already bundled"
fi
echo ""

# Step 2: Copy to Flutter Resources (for debug builds)
echo "📋 Step 2: Setting up Flutter debug environment..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  Platform: macOS"
    FLUTTER_RESOURCES="$PROJECT_ROOT/gui/macos/Runner/Resources"

    # Create directories
    mkdir -p "$FLUTTER_RESOURCES/bin"
    mkdir -p "$FLUTTER_RESOURCES/lib"

    # Copy binaries if they exist
    if [ -f "$PROJECT_ROOT/transmission-binaries/macos/transmission-daemon" ]; then
        cp "$PROJECT_ROOT/transmission-binaries/macos/transmission-daemon" "$FLUTTER_RESOURCES/bin/"
        chmod +x "$FLUTTER_RESOURCES/bin/transmission-daemon"
        echo "  ✅ Copied transmission-daemon"
    else
        echo "  ⚠️  transmission-daemon not found in transmission-binaries/"
        echo "     Run ./scripts/bundle-transmission.sh first"
        exit 1
    fi

    # Copy libs if they exist
    if [ -d "$PROJECT_ROOT/transmission-binaries/macos/lib" ]; then
        cp -r "$PROJECT_ROOT/transmission-binaries/macos/lib/"* "$FLUTTER_RESOURCES/lib/" 2>/dev/null || true
        echo "  ✅ Copied libraries"
    fi

    # Fix library paths to be relative
    echo "  🔧 Fixing library paths..."
    chmod +w "$FLUTTER_RESOURCES/bin/transmission-daemon"
    install_name_tool -change /opt/homebrew/opt/libevent/lib/libevent-2.1.7.dylib @executable_path/../Resources/lib/libevent-2.1.7.dylib "$FLUTTER_RESOURCES/bin/transmission-daemon" 2>/dev/null || true
    install_name_tool -change /opt/homebrew/opt/miniupnpc/lib/libminiupnpc.21.dylib @executable_path/../Resources/lib/libminiupnpc.21.dylib "$FLUTTER_RESOURCES/bin/transmission-daemon" 2>/dev/null || true
    # Also try Intel Mac paths
    install_name_tool -change /usr/local/opt/libevent/lib/libevent-2.1.7.dylib @executable_path/../Resources/lib/libevent-2.1.7.dylib "$FLUTTER_RESOURCES/bin/transmission-daemon" 2>/dev/null || true
    install_name_tool -change /usr/local/opt/miniupnpc/lib/libminiupnpc.21.dylib @executable_path/../Resources/lib/libminiupnpc.21.dylib "$FLUTTER_RESOURCES/bin/transmission-daemon" 2>/dev/null || true
    echo "  ✅ Library paths fixed"

    # Verify
    echo ""
    echo "  Verification:"
    ls -lh "$FLUTTER_RESOURCES/bin/transmission-daemon"
    echo "  Libraries:"
    ls -lh "$FLUTTER_RESOURCES/lib/"

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "  Platform: Linux"
    FLUTTER_RESOURCES="$PROJECT_ROOT/gui/linux-binaries"

    mkdir -p "$FLUTTER_RESOURCES/bin"

    if [ -f "$PROJECT_ROOT/transmission-binaries/linux/transmission-daemon" ]; then
        cp "$PROJECT_ROOT/transmission-binaries/linux/transmission-daemon" "$FLUTTER_RESOURCES/bin/"
        chmod +x "$FLUTTER_RESOURCES/bin/transmission-daemon"
        echo "  ✅ Copied transmission-daemon"
    else
        echo "  ⚠️  transmission-daemon not found"
        echo "     Run ./scripts/bundle-transmission.sh first"
        exit 1
    fi

else
    echo "  Platform: Windows (manual setup required)"
    echo "  Please copy transmission-daemon.exe to gui/windows-binaries/"
fi

echo ""

# Step 3: Install Flutter dependencies
echo "🎨 Step 3: Installing Flutter dependencies..."
cd "$PROJECT_ROOT/gui"
flutter pub get
echo ""

# Step 4: Verify setup
echo "✅ Development environment setup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next steps:"
echo ""
echo "1. Run the app in debug mode:"
echo "   cd gui"
echo "   flutter run -d macos"
echo ""
echo "2. Or open in Xcode:"
echo "   open gui/macos/Runner.xcworkspace"
echo ""
echo "3. Build for release:"
echo "   ./scripts/build-local-bundle.sh"
echo ""
echo "📍 Bundled transmission is now available in debug mode!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
