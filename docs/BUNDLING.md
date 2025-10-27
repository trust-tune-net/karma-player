# 📦 Transmission Bundling Guide

This guide explains how TrustTune bundles Transmission daemon with the application for a seamless user experience.

## Overview

Starting from version 0.4.0, TrustTune bundles `transmission-daemon` directly in the application package, eliminating the need for users to install Transmission separately.

## Architecture

### macOS
```
TrustTune.app/
└── Contents/
    ├── MacOS/
    │   └── trusttune_gui (Flutter executable)
    └── Resources/
        ├── bin/
        │   └── transmission-daemon (bundled binary)
        └── lib/
            ├── libevent-2.1.7.dylib
            └── libminiupnpc.21.dylib
```

### Windows
```
TrustTune/
├── trusttune_gui.exe
├── transmission-daemon.exe
└── *.dll (required libraries)
```

### Linux
```
TrustTune/
├── trusttune_gui
└── bin/
    └── transmission-daemon
```

## How It Works

### 1. DaemonManager Detection (daemon_manager.dart:11-36)

The Flutter app automatically detects bundled binaries:

```dart
String get daemonPath {
  if (kDebugMode) {
    // In debug: use system transmission
    return '/opt/homebrew/bin/transmission-daemon';
  } else {
    // In release: use bundled binary
    if (Platform.isMacOS) {
      return path.join(contentsDir, 'Resources', 'bin', 'transmission-daemon');
    } else if (Platform.isWindows) {
      return path.join(appDir, 'transmission-daemon.exe');
    } else {
      return path.join(appDir, 'bin', 'transmission-daemon');
    }
  }
}
```

### 2. Automatic Startup (daemon_manager.dart:74-144)

When the app needs to download a torrent:

1. Checks if system transmission is running
2. If not, starts the bundled binary
3. Configures it to use `~/Music/.transmission` for config
4. Sets download directory to `~/Music/`

### 3. Build Process

#### GitHub Actions (Automated)

The CI/CD pipeline automatically bundles transmission for each platform:

**macOS** (.github/workflows/build-release.yml:23-73)
- Installs transmission via Homebrew
- Copies binary and dependencies
- Bundles into Flutter app

**Windows** (.github/workflows/build-release.yml:100-154)
- Downloads official MSI
- Extracts transmission-daemon.exe
- Bundles with Flutter app

**Linux** (.github/workflows/build-release.yml:186-211)
- Installs from apt
- Copies binary
- Bundles with Flutter app

#### Local Development

For testing bundled builds locally:

```bash
# Bundle transmission binaries
./scripts/bundle-transmission.sh

# Build Flutter app with binaries
./scripts/build-local-bundle.sh

# Test the bundled app
open gui/build/macos/Build/Products/Release/trusttune_gui.app
```

## Platform-Specific Notes

### macOS

**Dynamic Libraries:**
The macOS binary depends on:
- `libevent-2.1.7.dylib` - Event notification library
- `libminiupnpc.21.dylib` - UPnP client library

These are bundled in `Contents/Resources/lib/` and the binary paths are updated to be relative.

**Homebrew Dependency:**
During build, we use Homebrew's transmission. The CI script:
1. Installs: `brew install transmission`
2. Copies: `$(which transmission-daemon)` → app bundle
3. Bundles dylibs from `/opt/homebrew/opt/*/lib/`

### Windows

**MSI Extraction:**
The Windows build downloads the official MSI and extracts:
- `transmission-daemon.exe`
- Required DLLs (openssl, curl, zlib, etc.)

**Installation Directory:**
Typically installed to: `C:\Program Files\Transmission\`

### Linux

**System Libraries:**
The Linux binary is dynamically linked to system libraries:
- `libc`, `libpthread`, `libm` (glibc - always present)
- `libevent`, `libminiupnpc` (usually pre-installed)

**Fallback Strategy:**
If libraries are missing, users can install: `sudo apt install transmission-daemon`

## Versioning

Current bundled version: **Transmission 4.0.5**

To update:
1. Change `TRANSMISSION_VERSION` in scripts
2. Test on all platforms
3. Update CHANGELOG.md

## Troubleshooting

### Binary Not Found

**Symptom:** App reports "transmission-daemon not found"

**Solution:**
1. Verify binary exists: `ls -la TrustTune.app/Contents/Resources/bin/`
2. Check permissions: `chmod +x transmission-daemon`
3. Test binary directly: `./transmission-daemon --version`

### Library Loading Errors (macOS)

**Symptom:** `dyld: Library not loaded: @rpath/libevent-2.1.7.dylib`

**Solution:**
1. Verify libs exist: `ls -la TrustTune.app/Contents/Resources/lib/`
2. Check binary paths: `otool -L transmission-daemon`
3. Re-run bundling script

### Missing DLLs (Windows)

**Symptom:** "The code execution cannot proceed because X.dll was not found"

**Solution:**
1. Ensure all DLLs from Transmission installation are copied
2. Check: `ldd transmission-daemon.exe` (via Git Bash)

## Security Considerations

### Binary Verification

We bundle official Transmission binaries from:
- **Source:** https://github.com/transmission/transmission/releases
- **Verification:** SHA256 checksums (future: add to CI)

### Sandboxing

The bundled daemon runs with:
- **No authentication** on localhost (safe: only local connections)
- **Port 9091** (RPC interface, localhost-only)
- **Config isolation:** `~/Music/.transmission/` (separate from system)

### Updates

Bundled transmission is updated with TrustTune releases. Users don't need to update separately.

## Development Workflow

### Testing Bundled Builds

```bash
# 1. Bundle transmission
./scripts/bundle-transmission.sh

# 2. Build with bundle
./scripts/build-local-bundle.sh

# 3. Test the app
open gui/build/macos/Build/Products/Release/trusttune_gui.app

# 4. Verify transmission starts
# Search for music in the app and check Downloads tab
```

### Debug Mode

In debug mode (`flutter run`), the app uses system-installed transmission:

```dart
if (kDebugMode) {
  return '/opt/homebrew/bin/transmission-daemon';
}
```

This allows faster iteration without rebuilding bundles.

### Release Mode

In release mode (`flutter build`), the app uses bundled binaries:

```bash
flutter build macos --release
# Uses: Contents/Resources/bin/transmission-daemon
```

## CI/CD Integration

### GitHub Actions Workflow

The build process runs on every tag push (`v*`):

1. **Checkout code**
2. **Install Transmission** (platform-specific)
3. **Bundle binaries** (scripts/bundle-transmission.sh)
4. **Build Flutter app** (flutter build <platform>)
5. **Copy binaries to bundle** (post-build step)
6. **Create archive** (ZIP/TAR.GZ)
7. **Upload to GitHub Releases**

### Adding New Platforms

To support a new platform (e.g., iOS, Android):

1. Add platform detection to `daemon_manager.dart`
2. Create bundling step in `.github/workflows/build-release.yml`
3. Update `scripts/bundle-transmission.sh`
4. Test thoroughly!

## Future Improvements

- [ ] Add SHA256 verification of binaries
- [ ] Support static linking (Linux)
- [ ] Add auto-update mechanism for bundled transmission
- [ ] Create AppImage/DMG with all dependencies
- [ ] Add binary signing for macOS/Windows

---

**Last Updated:** 2025-10-27
**Transmission Version:** 4.0.5
**Supported Platforms:** macOS, Windows, Linux
