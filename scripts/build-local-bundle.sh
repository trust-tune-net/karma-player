#!/bin/bash
# Build TrustTune locally with bundled Transmission
# For testing before pushing to CI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Building TrustTune with bundled Transmission (local test)"
echo ""

# Step 1: Bundle Transmission
echo "📦 Step 1: Bundling Transmission..."
"$SCRIPT_DIR/bundle-transmission.sh"
echo ""

# Step 2: Copy to Flutter resources
echo "📋 Step 2: Copying binaries to Flutter app..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  Platform: macOS"
    FLUTTER_RESOURCES="$PROJECT_ROOT/gui/macos/Runner/Resources"
    mkdir -p "$FLUTTER_RESOURCES/bin"
    mkdir -p "$FLUTTER_RESOURCES/lib"

    # Copy binaries
    if [ -f "$PROJECT_ROOT/transmission-binaries/macos/transmission-daemon" ]; then
        cp "$PROJECT_ROOT/transmission-binaries/macos/transmission-daemon" "$FLUTTER_RESOURCES/bin/"
        chmod +x "$FLUTTER_RESOURCES/bin/transmission-daemon"
        echo "  ✅ Copied transmission-daemon"
    fi

    # Copy libs
    if [ -d "$PROJECT_ROOT/transmission-binaries/macos/lib" ]; then
        cp -r "$PROJECT_ROOT/transmission-binaries/macos/lib/"* "$FLUTTER_RESOURCES/lib/" 2>/dev/null || true
        echo "  ✅ Copied libraries"
    fi

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "  Platform: Linux"
    FLUTTER_RESOURCES="$PROJECT_ROOT/gui/linux-binaries"
    mkdir -p "$FLUTTER_RESOURCES/bin"

    if [ -f "$PROJECT_ROOT/transmission-binaries/linux/transmission-daemon" ]; then
        cp "$PROJECT_ROOT/transmission-binaries/linux/transmission-daemon" "$FLUTTER_RESOURCES/bin/"
        chmod +x "$FLUTTER_RESOURCES/bin/transmission-daemon"
        echo "  ✅ Copied transmission-daemon"
    fi

else
    echo "  ⚠️  Windows bundling not yet automated"
    echo "  Please manually copy transmission-daemon.exe to gui/windows-binaries/"
fi

echo ""

# Step 3: Build Flutter app
echo "🔨 Step 3: Building Flutter app..."
cd "$PROJECT_ROOT/gui"

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  Building for macOS..."
    flutter build macos --release

    # Copy binaries to built app
    echo ""
    echo "📦 Step 4: Copying binaries to built app bundle..."
    APP_PATH="build/macos/Build/Products/Release/trusttune_gui.app"

    if [ -d "$APP_PATH" ]; then
        mkdir -p "$APP_PATH/Contents/Resources/bin"
        mkdir -p "$APP_PATH/Contents/Resources/lib"

        # Copy transmission binary
        if [ -f "macos/Runner/Resources/bin/transmission-daemon" ]; then
            cp "macos/Runner/Resources/bin/transmission-daemon" "$APP_PATH/Contents/Resources/bin/"
            chmod +x "$APP_PATH/Contents/Resources/bin/transmission-daemon"
            echo "  ✅ Transmission bundled in app"
        fi

        # Copy libs
        if [ -d "macos/Runner/Resources/lib" ]; then
            cp -r "macos/Runner/Resources/lib/"* "$APP_PATH/Contents/Resources/lib/" 2>/dev/null || true
            echo "  ✅ Libraries bundled in app"
        fi

        echo ""
        echo "✅ Build complete!"
        echo ""
        echo "📍 App location: $PROJECT_ROOT/gui/$APP_PATH"
        echo ""
        echo "🧪 Test it:"
        echo "   open \"$PROJECT_ROOT/gui/$APP_PATH\""
        echo ""

        # Verify binary is there
        if [ -f "$APP_PATH/Contents/Resources/bin/transmission-daemon" ]; then
            echo "✅ Transmission binary verified in bundle"
            ls -lh "$APP_PATH/Contents/Resources/bin/transmission-daemon"
        else
            echo "⚠️  Warning: Transmission binary not found in bundle!"
        fi
    fi

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "  Building for Linux..."
    flutter build linux --release

    # Copy binaries to built app
    BUILD_DIR="build/linux/x64/release/bundle"
    mkdir -p "$BUILD_DIR/bin"

    if [ -f "../transmission-binaries/linux/transmission-daemon" ]; then
        cp "../transmission-binaries/linux/transmission-daemon" "$BUILD_DIR/bin/"
        chmod +x "$BUILD_DIR/bin/transmission-daemon"
        echo "  ✅ Transmission bundled in app"
    fi

    echo ""
    echo "✅ Build complete!"
    echo "📍 App location: $PROJECT_ROOT/gui/$BUILD_DIR"
fi

cd "$PROJECT_ROOT"

echo ""
echo "═══════════════════════════════════════════════"
echo "✅ Local bundle build complete!"
echo "═══════════════════════════════════════════════"
