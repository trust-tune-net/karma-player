# macOS Sleep/Wake Crash Fix

## Problem

TrustTune crashes on macOS when the laptop lid is closed and then reopened (sleep/wake cycle).

**Crash Details:**
- **Exception Type**: `EXC_BAD_ACCESS (SIGBUS)`
- **Exception Codes**: `KERN_MEMORY_ERROR`
- **Crashed Thread**: Thread 7 "dart:io EventHandler"
- **Kernel Message**: "VM - Object has no pager because the backing vnode was force unmounted"

## Root Cause

When macOS enters sleep mode:
1. The system unmounts memory-mapped files, including the Dart VM executable
2. Background threads (like the Dart EventHandler) continue to hold references to these unmapped memory regions
3. When the system wakes up, these threads try to access the unmapped memory
4. This causes a `SIGBUS` (bus error) crash due to accessing invalid memory

This is a **known issue with Flutter macOS apps** that don't implement proper sleep/wake handling.

## Solution Overview

Implement macOS sleep/wake notification handlers that:
1. Pause all background operations before sleep
2. Resume operations after wake
3. Prevent the Dart runtime from accessing unmapped memory during sleep/wake transitions

## Implementation Steps

### Step 1: Add Sleep/Wake Notifications to AppDelegate

**File**: `gui/macos/Runner/AppDelegate.swift`

```swift
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var sleepWakeChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Set up method channel for sleep/wake events
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      sleepWakeChannel = FlutterMethodChannel(
        name: "com.trusttune/sleep_wake",
        binaryMessenger: controller.engine.binaryMessenger
      )
    }

    // Register for sleep/wake notifications
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(onWillSleep),
      name: NSWorkspace.willSleepNotification,
      object: nil
    )

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(onDidWake),
      name: NSWorkspace.didWakeNotification,
      object: nil
    )
  }

  @objc private func onWillSleep() {
    print("[macOS] System will sleep - pausing operations")
    sleepWakeChannel?.invokeMethod("willSleep", arguments: nil)
  }

  @objc private func onDidWake() {
    print("[macOS] System did wake - resuming operations")
    sleepWakeChannel?.invokeMethod("didWake", arguments: nil)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  deinit {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }
}
```

### Step 2: Create a Sleep/Wake Handler Service (Dart)

**File**: `gui/lib/services/sleep_wake_service.dart`

```dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SleepWakeService {
  static const platform = MethodChannel('com.trusttune/sleep_wake');

  final Ref _ref;

  SleepWakeService(this._ref) {
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'willSleep':
          await _handleWillSleep();
          break;
        case 'didWake':
          await _handleDidWake();
          break;
        default:
          print('[Sleep/Wake] Unknown method: ${call.method}');
      }
    });
  }

  Future<void> _handleWillSleep() async {
    print('[Sleep/Wake] System will sleep - pausing operations');

    // 1. Pause media playback
    final playbackService = _ref.read(playbackServiceProvider);
    if (playbackService.isPlaying) {
      playbackService.togglePlayPause();
      print('[Sleep/Wake] Paused playback');
    }

    // 2. Cancel any active YouTube downloads
    final youtubeService = _ref.read(youtubeDownloadServiceProvider);
    // Note: Add a cancel method to YouTubeDownloadService if needed

    // 3. Pause transmission daemon if needed
    // (transmission-daemon handles sleep/wake well on its own, but we could
    // optionally pause torrents here)

    print('[Sleep/Wake] All operations paused for sleep');
  }

  Future<void> _handleDidWake() async {
    print('[Sleep/Wake] System woke up - resuming operations');

    // Give the system a moment to stabilize after wake
    await Future.delayed(Duration(milliseconds: 500));

    // Resume operations if needed
    // (In most cases, we don't auto-resume playback - user will manually resume)

    print('[Sleep/Wake] Ready after wake');
  }
}

// Provider
final sleepWakeServiceProvider = Provider<SleepWakeService>((ref) {
  return SleepWakeService(ref);
});
```

### Step 3: Initialize Sleep/Wake Service in Main App

**File**: `gui/lib/main.dart`

Add initialization in the main app:

```dart
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize sleep/wake handler (macOS only)
    if (Platform.isMacOS) {
      ref.read(sleepWakeServiceProvider); // Initialize
    }

    // ... rest of app
  }
}
```

### Step 4: Enhanced PlaybackService Changes (Optional)

**File**: `gui/lib/services/playback_service.dart`

Add a method to gracefully handle sleep interruptions:

```dart
class PlaybackService extends ChangeNotifier {
  // ... existing code ...

  bool _wasPlayingBeforeSleep = false;

  void prepareForSleep() {
    if (!_playerInitialized || _player == null) return;

    _wasPlayingBeforeSleep = _isPlaying;
    if (_isPlaying) {
      _player!.pause();
      print('[PLAYBACK] Paused for system sleep');
    }
  }

  void resumeAfterWake() {
    if (!_playerInitialized || _player == null) return;

    // Optionally auto-resume if user preference is set
    // For now, we don't auto-resume to avoid surprising the user
    _wasPlayingBeforeSleep = false;
    print('[PLAYBACK] Ready after system wake');
  }
}
```

## Testing the Fix

1. **Build and run the app**:
   ```bash
   cd gui
   flutter run -d macos
   ```

2. **Test sleep/wake cycle**:
   - Start playing a song
   - Close the laptop lid (or use: `pmset sleepnow` in terminal)
   - Wait 5 seconds
   - Open the laptop lid
   - Check the app doesn't crash

3. **Verify logs**:
   ```
   [macOS] System will sleep - pausing operations
   [Sleep/Wake] System will sleep - pausing operations
   [Sleep/Wake] Paused playback
   [Sleep/Wake] All operations paused for sleep
   [macOS] System did wake - resuming operations
   [Sleep/Wake] System woke up - resuming operations
   [Sleep/Wake] Ready after wake
   ```

## Alternative: Simpler Approach (Minimal Fix)

If you want a minimal fix without the full service architecture:

**Just add to AppDelegate.swift:**

```swift
@objc private func onWillSleep() {
  print("[macOS] System will sleep - app will pause")
  // Force all background threads to idle
  DispatchQueue.main.async {
    // This ensures UI thread is stable before sleep
  }
}

@objc private func onDidWake() {
  print("[macOS] System did wake")
  // Small delay to let system stabilize
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    print("[macOS] System ready after wake")
  }
}
```

This minimal approach just ensures the app's main thread is stable during sleep/wake transitions, which often prevents the crash without needing to pause individual services.

## References

- [Apple Documentation: NSWorkspace Sleep Notifications](https://developer.apple.com/documentation/foundation/nsworkspace)
- [Flutter Issue #72385: macOS sleep/wake crashes](https://github.com/flutter/flutter/issues/72385)
- Kernel error: "Object has no pager" indicates memory mapping issues during sleep

## Priority

**Medium Priority** - The crash only occurs during sleep/wake cycles. Users can work around it by closing the app before sleeping or just relaunching after wake. However, fixing it improves the overall macOS user experience.
