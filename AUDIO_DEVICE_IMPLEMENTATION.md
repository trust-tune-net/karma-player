# Audio Device Implementation Plan

**Project**: TrustTune (karma-player)
**Goal**: Fix Bluetooth device enumeration + add audiophile-grade audio output control
**Current Issue**: media_kit's libmpv backend doesn't reliably enumerate Bluetooth devices on macOS

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│              Flutter UI Layer                           │
│  (SettingsScreen, PlaybackService)                      │
└─────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        ▼                                 ▼
┌──────────────────────┐      ┌─────────────────────────┐
│ AudioDeviceService   │      │  media_kit Player       │
│ (Enhanced)           │      │  (Playback Engine)      │
└──────────────────────┘      └─────────────────────────┘
        │                                 │
        ▼                                 ▼
┌──────────────────────┐      ┌─────────────────────────┐
│ Platform Channels    │      │  libmpv audio output    │
│ (Native Code)        │      │                         │
└──────────────────────┘      └─────────────────────────┘
        │
        ├─ macOS: CoreAudio APIs
        ├─ Windows: WASAPI
        ├─ Linux: PulseAudio/ALSA
        └─ Fallback: media_kit enumeration
```

**Key Principle**: Use platform-native APIs for device enumeration, keep media_kit for playback quality.

---

## Phase 1: Platform Channel Device Enumeration (Week 1)

### Objectives
- [ ] Create macOS platform channel for CoreAudio device enumeration
- [ ] Implement native Swift/ObjC code to list ALL audio devices
- [ ] Return comprehensive device metadata to Dart
- [ ] Replace current media_kit-only enumeration with hybrid approach
- [ ] Test with AirPods, Beats, USB DACs, built-in speakers

### Implementation Checklist

#### 1.1 Project Structure Setup
- [ ] Create `gui/macos/Runner/AudioDeviceChannel.swift`
- [ ] Create `gui/lib/services/platform/audio_device_platform.dart`
- [ ] Create `gui/lib/services/platform/audio_device_platform_macos.dart`
- [ ] Create `gui/lib/services/platform/audio_device_platform_fallback.dart`
- [ ] Update `gui/macos/Runner/AppDelegate.swift` to register channel

#### 1.2 Native macOS Implementation (Swift)
**File**: `gui/macos/Runner/AudioDeviceChannel.swift`

```swift
import Cocoa
import FlutterMacOS
import CoreAudio

class AudioDeviceChannel {
    static let channelName = "com.trusttune.audio_device"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger
        )

        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "enumerateDevices":
                result(enumerateAudioDevices())
            case "getDefaultDevice":
                result(getDefaultOutputDevice())
            case "setAudioDevice":
                if let args = call.arguments as? [String: Any],
                   let deviceId = args["deviceId"] as? String {
                    setOutputDevice(deviceId: deviceId, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing deviceId", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    static func enumerateAudioDevices() -> [[String: Any]] {
        var devices: [[String: Any]] = []

        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return devices }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        )

        guard status == noErr else { return devices }

        // Filter for output devices and get details
        for deviceId in audioDevices {
            if let deviceInfo = getDeviceInfo(deviceId: deviceId), deviceInfo["isOutput"] as? Bool == true {
                devices.append(deviceInfo)
            }
        }

        return devices
    }

    static func getDeviceInfo(deviceId: AudioDeviceID) -> [String: Any]? {
        var deviceInfo: [String: Any] = [:]

        // Get device name
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        var status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )

        guard status == noErr else { return nil }

        // Get UID (unique identifier)
        propertyAddress.mSelector = kAudioDevicePropertyDeviceUID
        var deviceUID: CFString = "" as CFString
        dataSize = UInt32(MemoryLayout<CFString>.size)
        status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceUID
        )

        guard status == noErr else { return nil }

        // Check if device is output
        propertyAddress.mSelector = kAudioDevicePropertyStreams
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        dataSize = 0
        status = AudioObjectGetPropertyDataSize(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        let isOutput = (status == noErr && dataSize > 0)

        // Get transport type (USB, Bluetooth, Built-in, etc.)
        propertyAddress.mSelector = kAudioDevicePropertyTransportType
        propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
        var transportType: UInt32 = 0
        dataSize = UInt32(MemoryLayout<UInt32>.size)
        status = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &transportType
        )

        let deviceType = getTransportTypeName(transportType: transportType)

        deviceInfo = [
            "id": deviceUID as String,
            "name": deviceName as String,
            "deviceId": String(deviceId),
            "isOutput": isOutput,
            "transportType": deviceType,
            "isBluetooth": (transportType == kAudioDeviceTransportTypeBluetooth),
            "isUSB": (transportType == kAudioDeviceTransportTypeUSB),
            "isBuiltIn": (transportType == kAudioDeviceTransportTypeBuiltIn),
            "isAirPlay": (transportType == kAudioDeviceTransportTypeAirPlay),
        ]

        return deviceInfo
    }

    static func getTransportTypeName(transportType: UInt32) -> String {
        switch transportType {
        case kAudioDeviceTransportTypeBluetooth:
            return "bluetooth"
        case kAudioDeviceTransportTypeBuiltIn:
            return "builtin"
        case kAudioDeviceTransportTypeUSB:
            return "usb"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplay"
        case kAudioDeviceTransportTypeDisplayPort:
            return "displayport"
        case kAudioDeviceTransportTypeHDMI:
            return "hdmi"
        default:
            return "other"
        }
    }

    static func getDefaultOutputDevice() -> [String: Any]? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceId: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceId
        )

        guard status == noErr else { return nil }
        return getDeviceInfo(deviceId: deviceId)
    }

    static func setOutputDevice(deviceId: String, result: @escaping FlutterResult) {
        // Note: We don't actually change the system default device
        // Instead, we'll pass this to media_kit via the Dart layer
        // Just return success - the actual device switching happens in Dart
        result(["success": true, "deviceId": deviceId])
    }
}
```

**Error Handling**:
- Expected errors (device disconnected during enumeration): Log only, don't send to GlitchTip
- Unexpected errors (API failures, permission issues): Send to GlitchTip

#### 1.3 Dart Platform Interface
**File**: `gui/lib/services/platform/audio_device_platform.dart`

```dart
import 'package:flutter/foundation.dart';

/// Platform-agnostic audio device metadata
class PlatformAudioDevice {
  final String id;
  final String name;
  final String transportType;
  final bool isBluetooth;
  final bool isUSB;
  final bool isBuiltIn;
  final bool isAirPlay;
  final bool isOutput;
  final String? deviceId; // Native device ID for reference

  PlatformAudioDevice({
    required this.id,
    required this.name,
    required this.transportType,
    required this.isBluetooth,
    required this.isUSB,
    required this.isBuiltIn,
    required this.isAirPlay,
    required this.isOutput,
    this.deviceId,
  });

  factory PlatformAudioDevice.fromMap(Map<String, dynamic> map) {
    return PlatformAudioDevice(
      id: map['id'] as String,
      name: map['name'] as String,
      transportType: map['transportType'] as String? ?? 'other',
      isBluetooth: map['isBluetooth'] as bool? ?? false,
      isUSB: map['isUSB'] as bool? ?? false,
      isBuiltIn: map['isBuiltIn'] as bool? ?? false,
      isAirPlay: map['isAirPlay'] as bool? ?? false,
      isOutput: map['isOutput'] as bool? ?? true,
      deviceId: map['deviceId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'transportType': transportType,
      'isBluetooth': isBluetooth,
      'isUSB': isUSB,
      'isBuiltIn': isBuiltIn,
      'isAirPlay': isAirPlay,
      'isOutput': isOutput,
      'deviceId': deviceId,
    };
  }
}

/// Abstract platform interface for audio device enumeration
abstract class AudioDevicePlatform {
  /// Enumerate all available audio output devices
  Future<List<PlatformAudioDevice>> enumerateDevices();

  /// Get the system default output device
  Future<PlatformAudioDevice?> getDefaultDevice();

  /// Set the audio output device (if supported by platform)
  Future<bool> setAudioDevice(String deviceId);

  /// Check if platform supports native enumeration
  bool get supportsNativeEnumeration;
}
```

**File**: `gui/lib/services/platform/audio_device_platform_macos.dart`

```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'audio_device_platform.dart';
import '../analytics_service.dart';

class AudioDevicePlatformMacOS implements AudioDevicePlatform {
  static const platform = MethodChannel('com.trusttune.audio_device');

  @override
  bool get supportsNativeEnumeration => Platform.isMacOS;

  @override
  Future<List<PlatformAudioDevice>> enumerateDevices() async {
    try {
      final List<dynamic> devices = await platform.invokeMethod('enumerateDevices');
      return devices
          .map((d) => PlatformAudioDevice.fromMap(Map<String, dynamic>.from(d)))
          .toList();
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatform] Error enumerating devices: ${e.message}');
      // This is an unexpected error - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_enumerate',
        extras: {
          'platform': 'macOS',
          'code': e.code,
        },
      );
      return [];
    } catch (e, stackTrace) {
      print('[AudioDevicePlatform] Unexpected error: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_enumerate_unknown',
        extras: {'platform': 'macOS'},
      );
      return [];
    }
  }

  @override
  Future<PlatformAudioDevice?> getDefaultDevice() async {
    try {
      final Map<dynamic, dynamic>? device =
          await platform.invokeMethod('getDefaultDevice');
      if (device == null) return null;
      return PlatformAudioDevice.fromMap(Map<String, dynamic>.from(device));
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatform] Error getting default device: ${e.message}');
      // This is an unexpected error - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_default',
        extras: {
          'platform': 'macOS',
          'code': e.code,
        },
      );
      return null;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatform] Unexpected error: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_default_unknown',
        extras: {'platform': 'macOS'},
      );
      return null;
    }
  }

  @override
  Future<bool> setAudioDevice(String deviceId) async {
    try {
      final result = await platform.invokeMethod('setAudioDevice', {
        'deviceId': deviceId,
      });
      return result['success'] as bool? ?? false;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatform] Error setting device: ${e.message}');
      // This could be expected (device disconnected) or unexpected (permission denied)
      // Send to GlitchTip to track patterns
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_set_device',
        extras: {
          'platform': 'macOS',
          'code': e.code,
          'deviceId': deviceId,
        },
      );
      return false;
    }
  }
}
```

**File**: `gui/lib/services/platform/audio_device_platform_fallback.dart`

```dart
import 'audio_device_platform.dart';

class AudioDevicePlatformFallback implements AudioDevicePlatform {
  @override
  bool get supportsNativeEnumeration => false;

  @override
  Future<List<PlatformAudioDevice>> enumerateDevices() async {
    // Return empty list - caller will fall back to media_kit
    return [];
  }

  @override
  Future<PlatformAudioDevice?> getDefaultDevice() async {
    return null;
  }

  @override
  Future<bool> setAudioDevice(String deviceId) async {
    return false;
  }
}
```

#### 1.4 Update AudioDeviceService
**File**: `gui/lib/services/audio_device_service.dart` (modifications)

```dart
// Add imports
import 'dart:io';
import 'platform/audio_device_platform.dart';
import 'platform/audio_device_platform_macos.dart';
import 'platform/audio_device_platform_fallback.dart';

class AudioDeviceService extends ChangeNotifier {
  // ... existing code ...

  // Platform-specific device enumeration
  late final AudioDevicePlatform _platform;

  // Enhanced device list combining platform + media_kit
  List<PlatformAudioDevice> _platformDevices = [];

  AudioDeviceService._internal() {
    // Initialize platform-specific implementation
    if (Platform.isMacOS) {
      _platform = AudioDevicePlatformMacOS();
    } else {
      _platform = AudioDevicePlatformFallback();
    }
  }

  Future<void> initialize() async {
    try {
      print('[AudioDevice] Initializing audio device service...');
      print('[AudioDevice] Platform: ${Platform.operatingSystem}');
      print('[AudioDevice] Native enumeration supported: ${_platform.supportsNativeEnumeration}');

      // Create temporary player for media_kit enumeration (fallback)
      _tempPlayer = Player();

      // Try platform-native enumeration first
      if (_platform.supportsNativeEnumeration) {
        await _refreshPlatformDevices();
      }

      // Also get media_kit devices (may have different coverage)
      await _refreshDevices();

      // Merge device lists (platform devices take priority)
      _mergeDeviceLists();

      // Listen for device changes
      _devicesSubscription = _tempPlayer!.stream.audioDevices.listen(
        (devices) async {
          print('[AudioDevice] Device list changed: ${devices.length} devices');
          await _refreshDevices();
          if (_platform.supportsNativeEnumeration) {
            await _refreshPlatformDevices();
          }
          _mergeDeviceLists();
        },
        onError: (error, stackTrace) {
          // Stream errors are expected on some platforms - log only
          print('[AudioDevice] Error listening to device changes: $error');
          ErrorHandler().logExpectedError(
            'audio_device_stream',
            error,
            stackTrace: stackTrace,
            extras: {'platform': Platform.operatingSystem},
          );
        },
      );

      // Load saved preference
      await _loadSavedDevice();

      print('[AudioDevice] ✅ Initialized successfully');
      print('[AudioDevice] Platform devices: ${_platformDevices.length}');
      print('[AudioDevice] Media_kit devices: ${_availableDevices.length}');

    } catch (e, stackTrace) {
      print('[AudioDevice] ❌ Failed to initialize: $e');
      // This is a critical initialization failure - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_service_init',
        extras: {
          'platform': Platform.operatingSystem,
          'native_supported': _platform.supportsNativeEnumeration,
        },
      );
    }
  }

  Future<void> _refreshPlatformDevices() async {
    try {
      final devices = await _platform.enumerateDevices();
      _platformDevices = devices;

      print('[AudioDevice] Platform enumeration: ${devices.length} devices');
      for (var device in devices) {
        print('[AudioDevice]   - ${device.name} (${device.transportType})');
        if (device.isBluetooth) {
          print('[AudioDevice]     ✅ Bluetooth device detected');
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      print('[AudioDevice] Error refreshing platform devices: $e');
      // Unexpected platform enumeration error - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_refresh',
        extras: {'platform': Platform.operatingSystem},
      );
    }
  }

  void _mergeDeviceLists() {
    // Priority: Platform devices with accurate metadata
    // If platform enumeration available, prefer those results
    if (_platform.supportsNativeEnumeration && _platformDevices.isNotEmpty) {
      print('[AudioDevice] Using platform-native device list (${_platformDevices.length} devices)');
    } else {
      print('[AudioDevice] Using media_kit device list (${_availableDevices.length} devices)');
    }
    notifyListeners();
  }

  // Expose platform devices for UI
  List<PlatformAudioDevice> get platformDevices => List.unmodifiable(_platformDevices);
  bool get hasPlatformDevices => _platformDevices.isNotEmpty;

  // ... rest of existing code ...
}
```

#### 1.5 Update Settings Screen UI
**File**: `gui/lib/screens/settings_screen.dart` (modifications)

Show both platform and media_kit devices, with visual distinction for Bluetooth devices properly detected via CoreAudio.

#### 1.6 Testing Checklist
- [ ] Test with AirPods (paired and connected)
- [ ] Test with AirPods (paired but not connected)
- [ ] Test with Beats headphones
- [ ] Test with USB DAC (if available)
- [ ] Test with Built-in speakers
- [ ] Test device switching during playback
- [ ] Test with no Bluetooth devices paired
- [ ] Verify GlitchTip only receives unexpected errors
- [ ] Verify console logs are clean and informative

---

## Phase 2: Exclusive Mode Support (Week 2)

### Objectives
- [ ] Add exclusive audio mode for audiophile playback
- [ ] Implement WASAPI Exclusive (Windows)
- [ ] Implement Integer Mode (macOS)
- [ ] Add UI toggle in settings
- [ ] Document sample rate handling

### Implementation Checklist

#### 2.1 macOS Integer Mode
- [ ] Detect if current device supports Integer Mode
- [ ] Add method channel to enable/disable Integer Mode
- [ ] Use `kAudioDevicePropertyHogMode` for exclusive access
- [ ] Handle conflicts with other apps

#### 2.2 Windows WASAPI Exclusive
- [ ] Create Windows platform channel (C++/Dart FFI)
- [ ] Implement `AUDCLNT_STREAMFLAGS_EXCLUSIVE` mode
- [ ] Handle format negotiation
- [ ] Graceful fallback on permission errors

#### 2.3 Settings UI
- [ ] Add "Exclusive Mode" toggle
- [ ] Show warning: "Prevents other apps from using audio"
- [ ] Display current sample rate/bit depth
- [ ] Add "Test" button to verify exclusive mode

#### 2.4 Error Handling
**Expected Errors** (log only, no GlitchTip):
- Device in use by another app
- User denies exclusive access

**Unexpected Errors** (send to GlitchTip):
- CoreAudio/WASAPI API failures
- Format mismatch errors
- Driver crashes

---

## Phase 3: Device Metadata Enhancement (Week 3)

### Objectives
- [ ] Report bit depth/sample rate capabilities
- [ ] Identify USB DAC chipsets
- [ ] Detect Bluetooth audio codecs (AAC/aptX/LDAC)
- [ ] Show device metadata in UI

### Implementation Checklist

#### 3.1 Sample Rate/Bit Depth Detection
- [ ] Query `kAudioDevicePropertyAvailableNominalSampleRates` (macOS)
- [ ] Query `kAudioDevicePropertyStreamFormat` for bit depth
- [ ] Store in `PlatformAudioDevice` extended metadata
- [ ] Display in device dropdown subtitle

#### 3.2 USB DAC Chipset Detection
- [ ] Parse USB vendor/product IDs
- [ ] Maintain chipset database (ESS, AKM, Burr-Brown, etc.)
- [ ] Show in device details: "ESS ES9038 DAC"

#### 3.3 Bluetooth Codec Detection
- [ ] Use `IOBluetooth` framework (macOS)
- [ ] Detect A2DP codec (SBC/AAC/aptX/LDAC)
- [ ] Show codec quality indicator in UI
- [ ] Warn if using lossy codec with FLAC playback

#### 3.4 UI Enhancements
- [ ] Device detail modal with full specs
- [ ] Color-code by quality (green=USB DAC, yellow=Bluetooth, gray=Built-in)
- [ ] Show warning icons for sample rate mismatches

---

## Phase 4: Linux Support (Optional - Week 4)

### Objectives
- [ ] Add PulseAudio device enumeration
- [ ] Add ALSA fallback for direct hardware access
- [ ] Test on Ubuntu, Arch Linux, Pop!_OS

### Implementation Checklist

#### 4.1 PulseAudio
- [ ] Create Linux platform channel
- [ ] Use `pactl list sinks` or native API
- [ ] Parse device names and properties

#### 4.2 ALSA
- [ ] Detect ALSA devices via `/proc/asound/cards`
- [ ] Implement direct hardware mode (`hw:X,Y`)
- [ ] Handle permission issues (audio group membership)

---

## Error Handling Guidelines

### Send to GlitchTip (Unexpected Errors)
- ✅ Platform API failures (CoreAudio/WASAPI crashes)
- ✅ Permission denied errors (unexpected)
- ✅ Invalid device IDs from OS
- ✅ Null pointer exceptions in native code
- ✅ Method channel communication failures
- ✅ Audio driver crashes

### Log Only (Expected Errors)
- ❌ Device disconnected during enumeration
- ❌ Device already in use (exclusive mode conflict)
- ❌ User unplugged device while playing
- ❌ Bluetooth device out of range
- ❌ No audio devices available (headless system)
- ❌ Stream listener errors (platform-specific)

### Implementation Pattern
```dart
try {
  // Native operation
} on PlatformException catch (e, stackTrace) {
  // Check if expected
  if (e.code == 'DEVICE_IN_USE' || e.code == 'DEVICE_DISCONNECTED') {
    ErrorHandler().logExpectedError('audio_device_expected', e);
  } else {
    // Unexpected - send to GlitchTip
    AnalyticsService().captureError(e, stackTrace, context: 'audio_device_platform');
  }
}
```

---

## Success Metrics

### Phase 1
- ✅ All Bluetooth devices show up on macOS (100% detection rate)
- ✅ AirPods, Beats, Sony, Bose all enumerated
- ✅ No regression in media_kit playback quality
- ✅ < 5% increase in app startup time

### Phase 2
- ✅ Exclusive mode works on macOS/Windows
- ✅ Bit-perfect playback verified with analyzer tool
- ✅ Clear UI warnings for exclusive mode

### Phase 3
- ✅ USB DACs show chipset info
- ✅ Bluetooth codec displayed
- ✅ Sample rate mismatch warnings

---

## Testing Plan

### Manual Testing
1. **Device Enumeration**: Connect 5+ different device types, verify all appear
2. **Playback**: Switch devices during playback, ensure smooth transition
3. **Bluetooth**: Test paired-but-not-connected devices
4. **USB DAC**: Test 96kHz, 192kHz, 384kHz playback
5. **Exclusive Mode**: Verify other apps can't play audio simultaneously

### Automated Testing
```dart
// Unit tests for AudioDevicePlatform
test('macOS enumeration returns at least built-in device', () async {
  final platform = AudioDevicePlatformMacOS();
  final devices = await platform.enumerateDevices();
  expect(devices.isNotEmpty, true);
});

// Integration tests
test('Bluetooth device shows correct transport type', () async {
  // Mock CoreAudio response
  // Verify isBluetooth flag is set
});
```

---

## Rollback Plan

If Phase 1 causes issues:
1. Feature flag: `useNativeEnumeration = false`
2. Fall back to media_kit-only enumeration
3. Keep platform channel code for future fixes
4. Roll back UI changes

---

## Documentation

### User-Facing
- [ ] Update README with Bluetooth device requirements
- [ ] Add FAQ: "Why isn't my Bluetooth device showing?"
- [ ] Document exclusive mode trade-offs

### Developer-Facing
- [ ] Document platform channel API
- [ ] Add comments to Swift/ObjC code
- [ ] Create architecture diagram
- [ ] Document error codes and meanings

---

## Future Enhancements (Post-MVP)

- [ ] Windows implementation (WASAPI enumeration)
- [ ] Linux implementation (PulseAudio/ALSA)
- [ ] Android USB DAC support
- [ ] iOS AirPlay device selection
- [ ] Device change notifications (hotplug support)
- [ ] Volume control bypass for audiophile mode
- [ ] DSD playback support detection
- [ ] Headroom/gain management
- [ ] Audio device profiles (save EQ per device)

---

**Last Updated**: 2025-11-02
**Status**: Phase 1 In Progress
