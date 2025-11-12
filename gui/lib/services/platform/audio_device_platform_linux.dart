import 'dart:io';
import 'package:flutter/services.dart';
import 'audio_device_platform.dart';
import '../analytics_service.dart';
import '../error_handler.dart';

class AudioDevicePlatformLinux implements AudioDevicePlatform {
  static const platform = MethodChannel('com.trusttune.audio_device');

  @override
  bool get supportsNativeEnumeration => Platform.isLinux;

  @override
  bool get supportsAirPlayRouting => false;

  @override
  bool get supportsCastRouting => false;

  @override
  Future<List<PlatformAudioDevice>> enumerateDevices() async {
    try {
      final List<dynamic> devices = await platform.invokeMethod('enumerateDevices');
      final deviceList = devices
          .map((d) => PlatformAudioDevice.fromMap(Map<String, dynamic>.from(d)))
          .toList();

      print('[AudioDevicePlatformLinux] Enumerated ${deviceList.length} devices');
      return deviceList;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformLinux] PlatformException enumerating devices: ${e.message}');

      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_enumerate',
        extras: {
          'platform': 'Linux',
          'code': e.code,
          'message': e.message,
        },
      );
      return [];
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformLinux] Unexpected error enumerating: $e');

      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_enumerate_unknown',
        extras: {'platform': 'Linux'},
      );
      return [];
    }
  }

  @override
  Future<PlatformAudioDevice?> getDefaultDevice() async {
    try {
      final Map<dynamic, dynamic>? device =
          await platform.invokeMethod('getDefaultDevice');
      if (device == null) {
        print('[AudioDevicePlatformLinux] No default device returned');
        return null;
      }

      final platformDevice = PlatformAudioDevice.fromMap(Map<String, dynamic>.from(device));
      print('[AudioDevicePlatformLinux] Default device: ${platformDevice.name}');
      return platformDevice;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformLinux] PlatformException getting default device: ${e.message}');

      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_default',
        extras: {
          'platform': 'Linux',
          'code': e.code,
          'message': e.message,
        },
      );
      return null;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformLinux] Unexpected error getting default: $e');

      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_default_unknown',
        extras: {'platform': 'Linux'},
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

      final success = result['success'] as bool? ?? false;
      print('[AudioDevicePlatformLinux] Device selection: $deviceId -> $success');
      return success;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformLinux] PlatformException setting device: ${e.message}');

      if (e.code == 'DEVICE_IN_USE' || e.code == 'DEVICE_DISCONNECTED') {
        ErrorHandler().logExpectedError(
          'audio_device_set_expected',
          e,
          stackTrace: stackTrace,
          extras: {
            'code': e.code,
            'deviceId': deviceId,
          },
        );
      } else {
        AnalyticsService().captureError(
          e,
          stackTrace,
          context: 'audio_device_platform_set_device',
          extras: {
            'platform': 'Linux',
            'code': e.code,
            'deviceId': deviceId,
            'message': e.message,
          },
        );
      }
      return false;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformLinux] Unexpected error setting device: $e');

      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_set_device_unknown',
        extras: {
          'platform': 'Linux',
          'deviceId': deviceId,
        },
      );
      return false;
    }
  }

  @override
  Future<bool> showAirPlayPicker() async {
    // Linux desktop environments surface routing through system mixers instead.
    return false;
  }

  @override
  Future<bool> showCastPicker() async {
    // No unified Cast picker available at the platform layer.
    return false;
  }

  @override
  Future<bool> openSystemSoundSettings() async {
    final attempts = <List<String>>[
      ['sh', '-c', 'pavucontrol &'],
      ['sh', '-c', 'gnome-control-center sound &'],
      ['sh', '-c', 'mate-volume-control &'],
    ];

    for (final command in attempts) {
      try {
        final result = await Process.run(command[0], command.sublist(1));
        if (result.exitCode == 0) {
          return true;
        }
      } catch (e) {
        // Ignore and try next option.
        print('[AudioDevicePlatformLinux] Sound settings command failed: $e');
      }
    }

    AnalyticsService().captureError(
      'sound_settings_unavailable',
      StackTrace.current,
      context: 'audio_device_platform_open_sound_settings',
      extras: {'platform': 'Linux'},
    );
    return false;
  }

  // PulseAudio doesn't have exclusive mode like WASAPI
  @override
  Future<bool> supportsExclusiveMode(String deviceId) async {
    return false;
  }

  @override
  Future<bool> enableExclusiveMode(String deviceId, bool enable) async {
    return false;
  }

  @override
  Future<Map<String, dynamic>?> getDeviceFormat(String deviceId) async {
    try {
      final result = await platform.invokeMethod('getDeviceFormat', {
        'deviceId': deviceId,
      });

      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('[AudioDevicePlatformLinux] Error getting format: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> getDeviceMetadata(String deviceId) async {
    try {
      final result = await platform.invokeMethod('getDeviceMetadata', {
        'deviceId': deviceId,
      });

      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('[AudioDevicePlatformLinux] Error getting metadata: $e');
      return null;
    }
  }
}
