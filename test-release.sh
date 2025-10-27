#!/bin/bash
# Test release build locally - simulates what end users will get
set -e

echo "🧪 Testing Release Build (simulates user experience)"
echo ""

# Step 1: Clean previous builds
echo "1️⃣ Cleaning previous builds..."
cd gui
flutter clean
cd ..

# Step 2: Bundle Transmission (like CI does)
echo ""
echo "2️⃣ Bundling Transmission..."
if ! command -v transmission-daemon &> /dev/null; then
    echo "❌ transmission-daemon not found"
    echo "Install with: brew install transmission"
    exit 1
fi

mkdir -p gui/macos/Runner/Resources/bin
mkdir -p gui/macos/Runner/Resources/lib

# Copy binary
cp $(which transmission-daemon) gui/macos/Runner/Resources/bin/
chmod +x gui/macos/Runner/Resources/bin/transmission-daemon

# Copy libraries
DYLIBS=$(otool -L $(which transmission-daemon) | grep -v '/usr/lib' | grep -v '/System' | awk '{print $1}' | tail -n +2)
for dylib in $DYLIBS; do
    if [ -f "$dylib" ]; then
        cp "$dylib" gui/macos/Runner/Resources/lib/
    fi
done

# Fix library paths (CRITICAL!) - use @loader_path (relative to binary location)
chmod +w gui/macos/Runner/Resources/bin/transmission-daemon
install_name_tool -change /opt/homebrew/opt/libevent/lib/libevent-2.1.7.dylib @loader_path/../lib/libevent-2.1.7.dylib gui/macos/Runner/Resources/bin/transmission-daemon 2>/dev/null || true
install_name_tool -change /opt/homebrew/opt/miniupnpc/lib/libminiupnpc.21.dylib @loader_path/../lib/libminiupnpc.21.dylib gui/macos/Runner/Resources/bin/transmission-daemon 2>/dev/null || true

# Re-sign binary after modifying it
codesign --force --sign - gui/macos/Runner/Resources/bin/transmission-daemon

echo "✅ Transmission bundled"

# Step 3: Build release
echo ""
echo "3️⃣ Building Flutter release..."
cd gui
flutter pub get
flutter build macos --release
cd ..

# Step 4: Copy binaries to built app (like CI does)
echo ""
echo "4️⃣ Copying binaries to app bundle..."
APP_PATH="gui/build/macos/Build/Products/Release/trusttune_gui.app"

mkdir -p "$APP_PATH/Contents/Resources/bin"
mkdir -p "$APP_PATH/Contents/Resources/lib"

cp gui/macos/Runner/Resources/bin/transmission-daemon "$APP_PATH/Contents/Resources/bin/"
chmod +x "$APP_PATH/Contents/Resources/bin/transmission-daemon"

cp -r gui/macos/Runner/Resources/lib/* "$APP_PATH/Contents/Resources/lib/"

echo "✅ Binaries copied"

# Step 5: Verify binary works
echo ""
echo "5️⃣ Testing bundled binary..."
if "$APP_PATH/Contents/Resources/bin/transmission-daemon" --version &> /dev/null; then
    echo "✅ Binary works!"
else
    echo "❌ Binary test failed!"
    echo ""
    echo "Debug info:"
    otool -L "$APP_PATH/Contents/Resources/bin/transmission-daemon"
    exit 1
fi

# Step 6: Kill any running transmission
echo ""
echo "6️⃣ Cleaning up old transmission processes..."
pkill -9 transmission-daemon 2>/dev/null || true
sleep 1

# Success!
echo ""
echo "═══════════════════════════════════════════════"
echo "✅ Release build ready for testing!"
echo "═══════════════════════════════════════════════"
echo ""
echo "📍 App location:"
echo "   $APP_PATH"
echo ""
echo "🧪 Test it now:"
echo "   open '$APP_PATH'"
echo ""
echo "✅ What to test:"
echo "   1. App opens without errors"
echo "   2. Search for 'radiohead'"
echo "   3. Click download"
echo "   4. Check Downloads tab for progress"
echo "   5. Verify transmission-daemon is running:"
echo "      ps aux | grep transmission-daemon"
echo ""
echo "If everything works, this is what users will get! 🎉"
echo ""
