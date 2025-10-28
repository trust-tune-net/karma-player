#!/bin/bash
# Copy Resources folder to app bundle during build
# This runs automatically as an Xcode build phase

set -e

echo "📦 Copying bundled resources to app bundle..."

RESOURCES_SRC="$SRCROOT/Runner/Resources"
RESOURCES_DEST="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Resources"

if [ -d "$RESOURCES_SRC/bin" ]; then
    echo "  Copying bin/..."
    # Remove existing bin directory if it exists (to avoid permission issues)
    if [ -d "$RESOURCES_DEST/bin" ]; then
        chmod -R u+w "$RESOURCES_DEST/bin" 2>/dev/null || true
        rm -rf "$RESOURCES_DEST/bin"
    fi
    mkdir -p "$RESOURCES_DEST/bin"
    cp -r "$RESOURCES_SRC/bin/"* "$RESOURCES_DEST/bin/"
    chmod +x "$RESOURCES_DEST/bin/"*

    # Fix library paths to use @loader_path (relative to binary, not main app)
    if [ -f "$RESOURCES_DEST/bin/transmission-daemon" ]; then
        echo "  Fixing library paths for transmission-daemon..."
        install_name_tool -change @executable_path/../Resources/lib/libevent-2.1.7.dylib @loader_path/../lib/libevent-2.1.7.dylib "$RESOURCES_DEST/bin/transmission-daemon" 2>/dev/null || true
        install_name_tool -change @executable_path/../Resources/lib/libminiupnpc.21.dylib @loader_path/../lib/libminiupnpc.21.dylib "$RESOURCES_DEST/bin/transmission-daemon" 2>/dev/null || true

        # Re-sign binary after modifying it
        echo "  Signing transmission-daemon..."
        codesign --force --sign - "$RESOURCES_DEST/bin/transmission-daemon"
    fi

    echo "  ✅ Binaries copied"
fi

if [ -d "$RESOURCES_SRC/lib" ]; then
    echo "  Copying lib/..."
    # Remove existing lib directory if it exists (to avoid permission issues)
    if [ -d "$RESOURCES_DEST/lib" ]; then
        chmod -R u+w "$RESOURCES_DEST/lib" 2>/dev/null || true
        rm -rf "$RESOURCES_DEST/lib"
    fi
    mkdir -p "$RESOURCES_DEST/lib"
    cp -r "$RESOURCES_SRC/lib/"* "$RESOURCES_DEST/lib/"

    # Sign all dylibs
    echo "  Signing dylibs..."
    for dylib in "$RESOURCES_DEST/lib/"*.dylib; do
        if [ -f "$dylib" ]; then
            codesign --force --sign - "$dylib" 2>/dev/null || true
        fi
    done

    echo "  ✅ Libraries copied"
fi

echo "✅ Resources copied to app bundle"
