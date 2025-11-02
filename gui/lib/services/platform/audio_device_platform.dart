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

  /// Get a friendly display name for the device
  String get friendlyName => name;

  /// Get device type enum for backward compatibility with existing UI code
  AudioDeviceType get deviceType {
    if (isBluetooth) return AudioDeviceType.bluetooth;
    if (isUSB) return AudioDeviceType.usb;
    if (isBuiltIn) return AudioDeviceType.builtIn;
    if (isAirPlay) return AudioDeviceType.airplay;
    if (transportType == 'hdmi' || transportType == 'displayport') {
      return AudioDeviceType.hdmi;
    }
    return AudioDeviceType.other;
  }
}

/// Enum for categorizing audio device types (for UI display)
/// Kept for backward compatibility with existing UI code
enum AudioDeviceType {
  builtIn,
  bluetooth,
  usb,
  hdmi,
  airplay,
  other,
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
