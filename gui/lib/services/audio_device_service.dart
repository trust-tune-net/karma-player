import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'app_settings.dart';
import 'analytics_service.dart';
import 'error_handler.dart';
import 'platform/audio_device_platform.dart';
import 'platform/audio_device_platform_macos.dart';
import 'platform/audio_device_platform_fallback.dart';

// AudioDeviceType is now exported from platform/audio_device_platform.dart

/// Helper to detect device type from MediaKit's AudioDevice
AudioDeviceType _detectDeviceType(AudioDevice device) {
  final name = device.name.toLowerCase();
  final description = device.description.toLowerCase();
  
  // Check for Bluetooth in both name and description (MediaKit may put it in description)
  final combined = '$name $description';
  
  // Enhanced Bluetooth detection patterns
  // Check for explicit Bluetooth indicators
  if (combined.contains('bluetooth') || 
      combined.contains('bt ') || 
      combined.contains(' bt') ||
      combined.contains('bt-') ||
      combined.contains('-bt') ||
      name.contains('airpods') ||
      description.contains('airpods')) {
    return AudioDeviceType.bluetooth;
  }
  
  // Check for common Bluetooth device brand names (often appear without "Bluetooth" in name)
  final bluetoothBrands = [
    'airpod', 'airpods',
    'beats', 'beats studio', 'beats solo', 'beats pro',
    'sony wh-', 'sony wf-', 'sony wf', // Sony WH/WF series are Bluetooth
    'bose', 'bose quietcomfort', 'bose soundsport',
    'jbl', 'jbl tune', 'jbl live', 'jbl flip',
    'sennheiser momentum', 'sennheiser cx',
    'akg', 'akg y', // AKG Y series are Bluetooth
    'shure', 'shure aonic',
    'jabra', 'jabra elite',
    'skullcandy', 'skullcandy indy',
    'hyperx cloud', 'hyperx cloud flight',
    'corsair void', 'corsair virtuoso',
    'steelseries arctis',
    'razer barracuda', 'razer hammerhead',
    'logitech g', 'logitech zone',
    'audio-technica ath-m',
    'philips shb',
    'anker soundcore', 'soundcore',
    'buds', 'earbuds', 'earbud', // Generic earbuds are often Bluetooth
    'tws', // True Wireless Stereo
    'wireless headphone', 'wireless earbud', 'wireless headset',
  ];
  
  for (var brand in bluetoothBrands) {
    if (combined.contains(brand)) {
      // Additional check: if it's a common Bluetooth brand, check if description confirms
      // Some USB headsets share names with Bluetooth models
      if (!combined.contains('usb') && !name.contains('usb')) {
        return AudioDeviceType.bluetooth;
      }
    }
  }
  
  // Check for Bluetooth headphone patterns (headphones with specific naming often indicate Bluetooth)
  if ((combined.contains('headphone') || combined.contains('headset') || combined.contains('earbud')) &&
      !combined.contains('usb') && !combined.contains('wired')) {
    // If it's a headphone/headset without USB/wired indicator, might be Bluetooth
    // But be conservative - only if we have other indicators
    if (combined.contains('pro') || combined.contains('max') || combined.contains('plus')) {
      // Pro/Max/Plus variants are often Bluetooth
      return AudioDeviceType.bluetooth;
    }
  }
  
  // Check for other device types
  if (combined.contains('usb') || name.contains('dac') || description.contains('dac')) {
    return AudioDeviceType.usb;
  } else if (name.contains('hdmi') || name.contains('displayport')) {
    return AudioDeviceType.hdmi;
  } else if (name.contains('airplay')) {
    return AudioDeviceType.airplay;
  } else if (name.contains('built-in') || 
             name.contains('internal') ||
             name.contains('speaker') ||
             name.contains('builtinspeaker') ||
             name.contains('builtinspeakerdevice')) {
    return AudioDeviceType.builtIn;
  }
  return AudioDeviceType.other;
}

/// Parse friendly name from MediaKit's technical device name
/// Examples:
/// - "auto" -> "System Default"
/// - "coreaudio/BuiltInSpeakerDevice" -> "Built-in Speakers"
/// - "coreaudio/Headphones" -> "Headphones"
/// - "bluetooth/DeviceName" -> "DeviceName"
String _parseFriendlyName(AudioDevice device) {
  final name = device.name;
  
  // Handle "auto" or empty
  if (name.isEmpty || name == 'auto' || name.toLowerCase() == 'auto') {
    return 'System Default';
  }
  
  // Handle macOS CoreAudio format: "coreaudio/DeviceName"
  if (name.contains('/')) {
    final parts = name.split('/');
    if (parts.length >= 2) {
      var devicePart = parts[1];
      
      // Clean up common CoreAudio naming patterns
      devicePart = devicePart
          .replaceAll('Device', '')
          .replaceAll('Output', '')
          .replaceAll('Input', '')
          .replaceAll('Capture', '');
      
      // Convert camelCase to Title Case with spaces
      devicePart = devicePart
          .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}')
          .trim();
      
      // Handle specific device names
      if (devicePart.toLowerCase().contains('builtinspeaker') ||
          devicePart.toLowerCase().contains('built-in speaker')) {
        return 'Built-in Speakers';
      } else if (devicePart.toLowerCase().contains('bluetooth')) {
        // Extract Bluetooth device name - remove "Bluetooth" prefix/suffix
        var btName = devicePart
            .replaceAll(RegExp(r'bluetooth', caseSensitive: false), '')
            .replaceAll(RegExp(r'BT', caseSensitive: false), '')
            .trim();
        
        // If name is empty after removing Bluetooth, try using description or original
        if (btName.isEmpty) {
          btName = device.description.isNotEmpty && device.description != device.name
              ? device.description
              : devicePart;
        }
        
        // Clean up common suffixes/prefixes
        btName = btName
            .replaceAll(RegExp(r'Device$', caseSensitive: false), '')
            .replaceAll(RegExp(r'Output$', caseSensitive: false), '')
            .trim();
        
        return btName.isNotEmpty ? btName : 'Bluetooth Device';
      } else if (devicePart.toLowerCase().contains('headphone')) {
        // Check if it's a Bluetooth headphone by description or pattern
        if (_detectDeviceType(device) == AudioDeviceType.bluetooth) {
          // It's a Bluetooth headphone - use device description or cleaned name
          final desc = device.description;
          if (desc.isNotEmpty && desc != device.name) {
            return desc;
          }
          return devicePart;
        }
        return 'Headphones';
      }
      
      // If we have a clean device name, use it
      if (devicePart.isNotEmpty) {
        // Capitalize first letter of each word
        final words = devicePart.split(' ');
        final capitalized = words.map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        }).join(' ');
        return capitalized;
      }
    }
    
    // Fallback: use the part after the slash
    return name.split('/').last;
  }
  
  // If no slash, try to clean up the name
  var cleaned = name
      .replaceAll('Device', '')
      .replaceAll('Output', '')
      .trim();
  
  if (cleaned.isEmpty) {
    return name; // Fallback to original
  }
  
  // Convert camelCase to Title Case
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  
  // Capitalize first letter of each word
  final words = cleaned.split(' ');
  return words.map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

/// Service for managing audio output device selection
class AudioDeviceService extends ChangeNotifier {
  static final AudioDeviceService _instance = AudioDeviceService._internal();
  factory AudioDeviceService() => _instance;

  AudioDeviceService._internal() {
    // Initialize platform-specific implementation
    if (Platform.isMacOS) {
      _platform = AudioDevicePlatformMacOS();
    } else {
      _platform = AudioDevicePlatformFallback();
    }
  }

  // MediaKit player instance (temporary, for device discovery)
  Player? _tempPlayer;

  // Available devices (using MediaKit's AudioDevice)
  List<AudioDevice> _availableDevices = [];
  AudioDevice? _selectedDevice;
  AudioDevice? _systemDefaultDevice;

  // Stream subscription for device changes
  StreamSubscription<List<AudioDevice>>? _devicesSubscription;

  // AppSettings reference
  final AppSettings _appSettings = AppSettings();

  // Platform-specific device enumeration
  late final AudioDevicePlatform _platform;

  // Enhanced device list from platform-native enumeration
  List<PlatformAudioDevice> _platformDevices = [];
  
  // Getters
  List<AudioDevice> get availableDevices => List.unmodifiable(_availableDevices);
  AudioDevice? get selectedDevice => _selectedDevice;
  AudioDevice? get systemDefaultDevice => _systemDefaultDevice;
  bool get hasDevices => _availableDevices.isNotEmpty;

  // Platform-native device getters
  List<PlatformAudioDevice> get platformDevices => List.unmodifiable(_platformDevices);
  bool get hasPlatformDevices => _platformDevices.isNotEmpty;
  bool get supportsNativeEnumeration => _platform.supportsNativeEnumeration;

  /// Get device type for UI display
  AudioDeviceType getDeviceType(AudioDevice device) {
    return _detectDeviceType(device);
  }

  /// Get friendly display name for a device
  String getFriendlyName(AudioDevice device) {
    return _parseFriendlyName(device);
  }

  /// Get technical/ID name for a device (for subtitle display)
  String getTechnicalName(AudioDevice device) {
    return device.name;
  }

  /// Initialize the service and discover available devices
  Future<void> initialize() async {
    try {
      print('[AudioDevice] Initializing audio device service...');
      print('[AudioDevice] Platform: ${Platform.operatingSystem}');
      print('[AudioDevice] Native enumeration supported: ${_platform.supportsNativeEnumeration}');

      // Create temporary player for device discovery
      _tempPlayer = Player();

      // Try platform-native enumeration first (macOS CoreAudio)
      if (_platform.supportsNativeEnumeration) {
        print('[AudioDevice] Using platform-native device enumeration');
        await _refreshPlatformDevices();
      }

      // Get initial device list from media_kit (fallback/supplement)
      await _refreshDevices();
      
      // On macOS, Bluetooth devices can take time to enumerate
      // Try multiple refresh attempts with increasing delays
      // Note: With platform-native enumeration, this is less necessary but kept for media_kit fallback
      for (var attempt = 1; attempt <= 2; attempt++) {
        final delay = attempt * 500; // 500ms, 1000ms
        print('[AudioDevice] Refresh attempt $attempt after ${delay}ms delay...');
        await Future.delayed(Duration(milliseconds: delay));

        if (_platform.supportsNativeEnumeration) {
          await _refreshPlatformDevices();
        }
        await _refreshDevices();

        // Check if we found Bluetooth devices (platform or media_kit)
        final platformBtCount = _platformDevices.where((d) => d.isBluetooth).length;
        final mediaKitBtCount = _availableDevices
            .where((d) => _detectDeviceType(d) == AudioDeviceType.bluetooth)
            .length;

        if ((platformBtCount > 0 || mediaKitBtCount > 0) && attempt > 1) {
          print('[AudioDevice] ✅ Found Bluetooth devices after $attempt attempts');
          print('[AudioDevice]    Platform: $platformBtCount, Media_kit: $mediaKitBtCount');
          break;
        }
      }
      
      // Listen for device changes
      _devicesSubscription = _tempPlayer!.stream.audioDevices.listen(
        (devices) async {
          print('[AudioDevice] Device list changed: ${devices.length} devices');
          print('[AudioDevice] Device names: ${devices.map((d) => d.name).join(", ")}');

          // Refresh both platform and media_kit device lists
          if (_platform.supportsNativeEnumeration) {
            await _refreshPlatformDevices();
          }
          await _refreshDevices();
        },
        onError: (error, stackTrace) {
          // Stream errors may be platform-specific limitations - log only
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

      print('[AudioDevice] ✅ Initialized successfully on ${Platform.operatingSystem}');
      print('[AudioDevice]    Platform devices: ${_platformDevices.length}');
      print('[AudioDevice]    Media_kit devices: ${_availableDevices.length}');

      // Log Bluetooth device counts
      final platformBtCount = _platformDevices.where((d) => d.isBluetooth).length;
      final mediaKitBtCount = _availableDevices
          .where((d) => _detectDeviceType(d) == AudioDeviceType.bluetooth)
          .length;

      if (platformBtCount > 0 || mediaKitBtCount > 0) {
        print('[AudioDevice]    Bluetooth devices: Platform=$platformBtCount, Media_kit=$mediaKitBtCount');
      }

      // Log platform-specific device info for debugging
      if (_platformDevices.isNotEmpty) {
        print('[AudioDevice] Platform devices:');
        for (var device in _platformDevices) {
          final type = device.isBluetooth ? '🔵 BT' : device.isUSB ? '🔌 USB' : '🔊';
          print('[AudioDevice]   $type ${device.name}');
        }
      } else if (_availableDevices.isNotEmpty) {
        final deviceNames = _availableDevices.map((d) => d.name).join(', ');
        print('[AudioDevice] Media_kit devices: $deviceNames');
      }
    } catch (e, stackTrace) {
      print('[AudioDevice] ❌ Failed to initialize: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_service_init',
      );
    }
  }

  /// Refresh the list of available devices
  Future<void> _refreshDevices() async {
    try {
      if (_tempPlayer == null) return;
      
      // Give MediaKit a moment to enumerate devices (especially Bluetooth on macOS)
      // Some devices may not appear immediately, especially Bluetooth
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Try to force MediaKit to refresh device list
      // On macOS, sometimes we need to trigger device enumeration
      try {
        // Access the state which may trigger device enumeration
        final state = _tempPlayer!.state;
        // Access audioDevices which may trigger enumeration
        // Some platforms need this access to enumerate
      } catch (e) {
        print('[AudioDevice] Note: Could not access player state for enumeration trigger: $e');
      }
      
      // Small additional delay after triggering enumeration
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Get devices from MediaKit (returns List<AudioDevice>)
      final devices = _tempPlayer!.state.audioDevices;
      print('[AudioDevice] Found ${devices.length} devices');
      
      // Debug: Comprehensive logging of ALL device properties
      print('[AudioDevice] ========== DETAILED DEVICE ENUMERATION ==========');
      print('[AudioDevice] Platform: ${Platform.operatingSystem}');
      print('[AudioDevice] Total devices found: ${devices.length}');
      print('[AudioDevice] ------------------------------------------------');
      
      for (var i = 0; i < devices.length; i++) {
        final device = devices[i];
        print('[AudioDevice] Device #${i + 1}:');
        print('[AudioDevice]   - name: "${device.name}"');
        print('[AudioDevice]   - description: "${device.description}"');
        
        // Try to access any other properties via reflection/toString
        try {
          final deviceStr = device.toString();
          if (deviceStr != device.name && deviceStr.contains('AudioDevice')) {
            print('[AudioDevice]   - toString: "$deviceStr"');
          }
        } catch (e) {
          // Ignore toString errors
        }
        
        // Analyze device for Bluetooth detection
        final lowerName = device.name.toLowerCase();
        final lowerDesc = device.description.toLowerCase();
        final detectedType = _detectDeviceType(device);
        
        print('[AudioDevice]   - Detected type: $detectedType');
        
        // Check for potential Bluetooth devices that aren't being detected
        if (detectedType != AudioDeviceType.bluetooth) {
          // Look for common Bluetooth device name patterns
          final btPatterns = [
            'airpod', 'beats', 'sony wh', 'sony wf', 'bose', 'jbl',
            'sennheiser', 'akg', 'shure', 'jabra', 'skullcandy',
            'hyperx', 'corsair', 'steelseries', 'razer', 'logitech',
            'audio-technica', 'philips', 'anker', 'soundcore'
          ];
          
          bool mightBeBluetooth = false;
          for (var pattern in btPatterns) {
            if (lowerName.contains(pattern) || lowerDesc.contains(pattern)) {
              mightBeBluetooth = true;
              print('[AudioDevice]   - ⚠️  Potential Bluetooth device (name pattern: "$pattern")');
              break;
            }
          }
          
          // Check for CoreAudio UUID patterns that might indicate Bluetooth
          if (device.name.contains('-') && device.name.length > 20) {
            // macOS CoreAudio devices sometimes have UUID-like identifiers
            print('[AudioDevice]   - ⚠️  Device has UUID-like identifier (might be Bluetooth)');
          }
        } else {
          print('[AudioDevice]   - ✅ Confirmed as Bluetooth device');
        }
        
        print('[AudioDevice] ------------------------------------------------');
      }
      
      print('[AudioDevice] ================================================');
      
      // Use MediaKit's AudioDevice directly
      _availableDevices = List.from(devices);
      
      // If no devices found, we'll just have an empty list
      // MediaKit should always return at least system default
      // This can happen on some platforms during initialization - expected
      if (_availableDevices.isEmpty) {
        print('[AudioDevice] ⚠️  No audio devices found (may be platform-specific)');
        // Log as expected - some platforms may not expose devices immediately
        ErrorHandler().logExpectedError(
          'audio_device_refresh_no_devices',
          'No audio devices available',
          extras: {
            'platform': Platform.operatingSystem,
            'device_count': 0,
          },
        );
      } else {
        // Try to identify system default (usually first one or has specific name)
        try {
          _systemDefaultDevice = _availableDevices.firstWhere(
            (d) => d.name.toLowerCase().contains('default') || 
                   d.name.isEmpty,
            orElse: () => _availableDevices.first,
          );
        } catch (e) {
          _systemDefaultDevice = _availableDevices.first;
        }
      }
      
      // If selected device is no longer available, reset to system default
      // This is expected when user unplugs device - log only, don't report to GlitchTip
      if (_selectedDevice != null && 
          !_availableDevices.any((d) => d.name == _selectedDevice!.name)) {
        final disconnectedDeviceName = _selectedDevice!.name;
        print('[AudioDevice] ⚠️  Selected device "$disconnectedDeviceName" no longer available');
        print('[AudioDevice] Resetting to system default device');
        
        // Log as expected error (user unplugged device)
        ErrorHandler().logExpectedError(
          'audio_device_disconnected',
          'Selected device disconnected',
          extras: {
            'device_name': disconnectedDeviceName,
            'platform': Platform.operatingSystem,
          },
        );
        
        _selectedDevice = _systemDefaultDevice;
        await _saveDevicePreference();
        notifyListeners(); // Notify that device changed due to disconnection
      }
      
      notifyListeners();
      print('[AudioDevice] ✓ Refreshed: ${_availableDevices.length} devices available');
    } catch (e, stackTrace) {
      print('[AudioDevice] Error refreshing devices: $e');
      // This could be a real error (API violation, memory issue) - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_refresh',
        extras: {
          'platform': Platform.operatingSystem,
          'device_count': _availableDevices.length,
        },
      );
    }
  }

  /// Refresh platform-native device list (macOS CoreAudio, Windows WASAPI, etc.)
  Future<void> _refreshPlatformDevices() async {
    try {
      final devices = await _platform.enumerateDevices();
      _platformDevices = devices;

      print('[AudioDevice] Platform enumeration: ${devices.length} devices');

      // Log Bluetooth devices specifically
      final bluetoothDevices = devices.where((d) => d.isBluetooth).toList();
      if (bluetoothDevices.isNotEmpty) {
        print('[AudioDevice] ✅ Found ${bluetoothDevices.length} Bluetooth device(s) via platform API:');
        for (var device in bluetoothDevices) {
          print('[AudioDevice]   🔵 ${device.name}');
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      print('[AudioDevice] Error refreshing platform devices: $e');

      // Unexpected platform enumeration error - report to GlitchTip
      // This should not happen if CoreAudio is working correctly
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_refresh',
        extras: {
          'platform': Platform.operatingSystem,
          'supportsNative': _platform.supportsNativeEnumeration,
        },
      );
    }
  }

  /// Select an audio device
  Future<void> selectDevice(AudioDevice device) async {
    try {
      print('[AudioDevice] Selecting device: ${device.name}');
      
      _selectedDevice = device;
      await _saveDevicePreference();
      
      notifyListeners();
      
      print('[AudioDevice] ✓ Device selected: ${device.name}');
    } catch (e, stackTrace) {
      print('[AudioDevice] Error selecting device: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_select',
        extras: {'device_name': device.name},
      );
    }
  }

  /// Get the AudioDevice object for MediaKit Player.setAudioDevice()
  AudioDevice? getDeviceForPlayer() {
    if (_selectedDevice == null) {
      return null; // Use system default
    }
    return _selectedDevice;
  }

  /// Load saved device preference from AppSettings
  Future<void> _loadSavedDevice() async {
    try {
      final savedDeviceName = _appSettings.selectedAudioDeviceId;
      if (savedDeviceName != null && savedDeviceName.isNotEmpty) {
        try {
          final device = _availableDevices.firstWhere(
            (d) => d.name == savedDeviceName,
            orElse: () => _systemDefaultDevice ?? _availableDevices.first,
          );
          _selectedDevice = device;
          print('[AudioDevice] Loaded saved device: ${device.name}');
        } catch (e) {
          // Device not found when loading saved preference - expected (user unplugged)
          _selectedDevice = _systemDefaultDevice;
          print('[AudioDevice] Saved device "$savedDeviceName" not found, using system default');
          // Log as expected error - don't report to GlitchTip
          ErrorHandler().logExpectedError(
            'audio_device_load_preference_not_found',
            'Saved device not available',
            extras: {
              'saved_device_name': savedDeviceName,
              'platform': Platform.operatingSystem,
            },
          );
        }
      } else {
        _selectedDevice = _systemDefaultDevice;
        print('[AudioDevice] No saved device, using system default');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      print('[AudioDevice] Error loading saved device: $e');
      // This is an unexpected error in loading - could indicate data corruption
      // Report to GlitchTip but also log
      ErrorHandler().logExpectedError(
        'audio_device_load_preference_error',
        e,
        stackTrace: stackTrace,
      );
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_load_preference',
        extras: {'platform': Platform.operatingSystem},
      );
      _selectedDevice = _systemDefaultDevice;
    }
  }

  /// Save device preference to AppSettings
  Future<void> _saveDevicePreference() async {
    try {
      await _appSettings.saveSelectedAudioDevice(
        _selectedDevice?.name ?? '',
      );
    } catch (e, stackTrace) {
      print('[AudioDevice] Error saving device preference: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_save_preference',
      );
    }
  }

  /// Refresh device list manually (can be called from UI)
  /// This forces a re-enumeration which may pick up newly connected Bluetooth devices
  Future<void> refreshDevices() async {
    print('[AudioDevice] Manual refresh requested by user');

    // Force a refresh by waiting and checking multiple times
    // Bluetooth devices may take a moment to appear
    if (_platform.supportsNativeEnumeration) {
      await _refreshPlatformDevices();
    }
    await _refreshDevices();

    await Future.delayed(const Duration(milliseconds: 300));
    if (_platform.supportsNativeEnumeration) {
      await _refreshPlatformDevices();
    }
    await _refreshDevices();

    await Future.delayed(const Duration(milliseconds: 500));
    if (_platform.supportsNativeEnumeration) {
      await _refreshPlatformDevices();
    }
    await _refreshDevices();

    print('[AudioDevice] Manual refresh complete:');
    print('[AudioDevice]   Platform devices: ${_platformDevices.length}');
    print('[AudioDevice]   Media_kit devices: ${_availableDevices.length}');

    // Log device types found
    final platformBtCount = _platformDevices.where((d) => d.isBluetooth).length;
    final mediaKitBtCount = _availableDevices.where((d) => _detectDeviceType(d) == AudioDeviceType.bluetooth).length;

    if (platformBtCount > 0 || mediaKitBtCount > 0) {
      print('[AudioDevice] ✅ Found Bluetooth device(s): Platform=$platformBtCount, Media_kit=$mediaKitBtCount');
    } else if (_platform.supportsNativeEnumeration) {
      print('[AudioDevice] ⚠️  No Bluetooth devices found via CoreAudio. Make sure Bluetooth devices are:');
      print('[AudioDevice]    1. Connected and paired to your Mac');
      print('[AudioDevice]    2. Showing in System Settings > Sound');
      print('[AudioDevice]    3. Not in use exclusively by another application');
    }
  }

  /// Dispose and cleanup
  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _tempPlayer?.dispose();
    _tempPlayer = null;
    super.dispose();
  }
}
