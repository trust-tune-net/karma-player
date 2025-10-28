# 🛠️ TrustTune Development Guide

## Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone https://github.com/trust-tune-net/karma-player.git
cd karma-player

# Run setup script (bundles transmission for debug mode)
./scripts/setup-dev.sh
```

### 2. Run the App

```bash
cd gui
flutter run -d macos  # or windows/linux
```

The app will now work in debug mode with bundled Transmission!

## Development Environment

### Prerequisites

**macOS:**
- Flutter 3.35+
- Xcode (latest)
- Transmission (for bundling): `brew install transmission`

**Windows:**
- Flutter 3.35+
- Visual Studio 2022
- Transmission MSI (downloaded by scripts)

**Linux:**
- Flutter 3.35+
- Build tools: `sudo apt install build-essential`
- Transmission: `sudo apt install transmission-daemon`

### First-Time Setup

The `setup-dev.sh` script does:
1. Bundles Transmission from your system installation
2. Copies binaries to Flutter Resources folder
3. Installs Flutter dependencies
4. Verifies setup

**Manual setup (if script fails):**

```bash
# 1. Bundle transmission
./scripts/bundle-transmission.sh

# 2. Copy to Flutter Resources (macOS)
mkdir -p gui/macos/Runner/Resources/bin
mkdir -p gui/macos/Runner/Resources/lib
cp transmission-binaries/macos/transmission-daemon gui/macos/Runner/Resources/bin/
cp transmission-binaries/macos/lib/* gui/macos/Runner/Resources/lib/

# 3. Install Flutter deps
cd gui && flutter pub get
```

## Project Structure

```
karma-player/
├── gui/                          # Flutter desktop app
│   ├── lib/
│   │   ├── main.dart            # App entry point
│   │   ├── models/              # Data models
│   │   ├── services/            # Business logic
│   │   │   ├── daemon_manager.dart   # Transmission lifecycle
│   │   │   └── transmission_client.dart  # RPC client
│   │   ├── screens/             # UI screens
│   │   └── widgets/             # Reusable components
│   └── macos/Runner/Resources/  # Bundled binaries (debug mode)
│       ├── bin/transmission-daemon
│       └── lib/*.dylib
├── karma_player/                # Python backend (CLI/API)
│   ├── api/                     # FastAPI servers
│   ├── services/                # Core services
│   │   ├── ai/                  # AI integration
│   │   ├── search/              # Multi-source search
│   │   └── torrent/             # Download management
│   └── models/                  # Data models
├── scripts/                     # Build/dev scripts
│   ├── setup-dev.sh            # Dev environment setup
│   ├── bundle-transmission.sh  # Bundle binaries
│   └── build-local-bundle.sh   # Local release build
├── transmission-binaries/       # Platform-specific binaries
│   ├── macos/
│   ├── windows/
│   └── linux/
└── docs/                        # Documentation
```

## Debug vs Release Modes

### Debug Mode (`flutter run`)

**Binary Location:**
```
gui/macos/Runner/Resources/bin/transmission-daemon
```

**How It Works:**
- `daemon_manager.dart` checks bundled path first
- Fallbacks to system transmission if bundled not found
- Allows quick iteration without rebuilding bundles

**Setup:**
Run `./scripts/setup-dev.sh` once

### Release Mode (`flutter build`)

**Binary Location:**
```
build/macos/Build/Products/Release/TrustTune.app/
  Contents/Resources/bin/transmission-daemon
```

**How It Works:**
- Build scripts copy binaries to final app bundle
- Fully self-contained app (no system dependencies)

**Build:**
```bash
./scripts/build-local-bundle.sh  # Local testing
# or
git tag v0.x.x && git push origin v0.x.x  # CI/CD build
```

## Common Tasks

### Running the App

```bash
# Debug mode
cd gui
flutter run -d macos

# With hot reload
flutter run -d macos --hot

# Release mode (faster, production-like)
flutter run -d macos --release
```

### Testing Transmission Integration

```bash
# 1. Start app in debug mode
cd gui && flutter run -d macos

# 2. In app: Search for music
# 3. Click download
# 4. Check terminal for daemon logs:
#    "Starting daemon from: /path/to/transmission-daemon"
#    "Daemon started successfully (PID: 12345)"

# 5. Verify daemon is running
ps aux | grep transmission-daemon

# 6. Check downloads tab in app
```

### Building for Release

**Local build (testing):**
```bash
./scripts/build-local-bundle.sh
open gui/build/macos/Build/Products/Release/trusttune_gui.app
```

**Full release (CI/CD):**
```bash
# Update version in pubspec.yaml and pyproject.toml
# Commit changes
git tag v0.4.0
git push origin v0.4.0

# GitHub Actions will:
# - Build for all platforms
# - Bundle transmission
# - Create release with downloads
```

### Updating Bundled Transmission

When a new Transmission version is released:

1. Update version in scripts:
```bash
# scripts/bundle-transmission.sh
TRANSMISSION_VERSION="4.0.6"  # Update this

# .github/workflows/build-release.yml
TRANSMISSION_VERSION="4.0.6"  # Update this
```

2. Re-bundle:
```bash
rm -rf transmission-binaries/
./scripts/bundle-transmission.sh
./scripts/setup-dev.sh
```

3. Test thoroughly on all platforms

4. Update CHANGELOG.md

## Troubleshooting

### "Daemon binary not found"

**Problem:** App can't find transmission-daemon

**Solution:**
```bash
# Re-run setup
./scripts/setup-dev.sh

# Or manually verify:
ls -la gui/macos/Runner/Resources/bin/transmission-daemon

# Should show: -rwxr-xr-x ... transmission-daemon
```

### "Library not loaded" (macOS)

**Problem:** Missing dylibs

**Solution:**
```bash
# Check libs exist
ls -la gui/macos/Runner/Resources/lib/

# Should show:
# libevent-2.1.7.dylib
# libminiupnpc.21.dylib

# Re-copy if missing:
cp transmission-binaries/macos/lib/* gui/macos/Runner/Resources/lib/
```

### Hot Reload Doesn't Work

**Problem:** Changes not showing

**Solution:**
```bash
# Hot reload doesn't work for native changes
# Use hot restart instead: press 'R' in terminal

# Or restart completely:
# Press 'q' to quit, then flutter run again
```

### Clean Build

If things get weird:

```bash
cd gui

# Clean Flutter build
flutter clean
flutter pub get

# Clean Xcode (macOS)
rm -rf macos/Pods
rm macos/Podfile.lock
cd macos && pod install && cd ..

# Rebuild
flutter run -d macos
```

## Code Style

### Dart (Flutter)
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `flutter analyze` before committing
- Format: `flutter format .`

### Python (Backend)
- Follow PEP 8
- Use `black` for formatting
- Use `ruff` for linting

### Git Workflow

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes
# ... code ...

# 3. Test
cd gui && flutter analyze
flutter test

# 4. Commit (concise one-liner)
git add .
git commit -m "Add feature X"

# 5. Push
git push origin feature/my-feature

# 6. Open PR on GitHub
```

## Resources

- **Flutter Docs:** https://flutter.dev/docs
- **Transmission RPC:** https://github.com/transmission/transmission/blob/main/docs/rpc-spec.md
- **TrustTune Architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Plugin Architecture:** [docs/PLUGIN_ARCHITECTURE.md](docs/PLUGIN_ARCHITECTURE.md)
- **Bundling Guide:** [docs/BUNDLING.md](docs/BUNDLING.md)

## Getting Help

- **Issues:** https://github.com/trust-tune-net/karma-player/issues
- **Discussions:** https://github.com/trust-tune-net/karma-player/discussions

---

**Happy coding!** 🎵✨
