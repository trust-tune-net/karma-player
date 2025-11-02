import 'dart:io';
import 'package:flutter/services.dart';
import 'audio_device_platform.dart';
import '../analytics_service.dart';
import '../error_handler.dart';

class AudioDevicePlatformWindows implements AudioDevicePlatform {
  static const platform = MethodChannel('com.trusttune.audio_device');

  @override
  bool get supportsNativeEnumeration => Platform.isWindows;

  @override
  Future<List<PlatformAudioDevice>> enumerateDevices() async {
    try {
      final List<dynamic> devices = await platform.invokeMethod('enumerateDevices');
      final deviceList = devices
          .map((d) => PlatformAudioDevice.fromMap(Map<String, dynamic>.from(d)))
          .toList();

      print('[AudioDevicePlatformWindows] Enumerated ${deviceList.length} devices');
      return deviceList;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformWindows] PlatformException enumerating devices: ${e.message}');

      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_enumerate',
        extras: {
          'platform': 'Windows',
          'code': e.code,
          'message': e.message,
        },
      );
      return [];
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformWindows] Unexpected error enumerating: $e');

      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_enumerate_unknown',
        extras: {'platform': 'Windows'},
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
        print('[AudioDevicePlatformWindows] No default device returned');
        return null;
      }

      final platformDevice = PlatformAudioDevice.fromMap(Map<String, dynamic>.from(device));
      print('[AudioDevicePlatformWindows] Default device: ${platformDevice.name}');
      return platformDevice;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformWindows] PlatformException getting default device: ${e.message}');

      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_default',
        extras: {
          'platform': 'Windows',
          'code': e.code,
          'message': e.message,
        },
      );
      return null;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformWindows] Unexpected error getting default: $e');

      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_default_unknown',
        extras: {'platform': 'Windows'},
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
      print('[AudioDevicePlatformWindows] Device selection: $deviceId -> $success');
      return success;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformWindows] PlatformException setting device: ${e.message}');

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
            'platform': 'Windows',
            'code': e.code,
            'deviceId': deviceId,
            'message': e.message,
          },
        );
      }
      return false;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformWindows] Unexpected error setting device: $e');

      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_set_device_unknown',
        extras: {
          'platform': 'Windows',
          'deviceId': deviceId,
        },
      );
      return false;
    }
  }

  // WASAPI Exclusive Mode Support
  @override
  Future<bool> supportsExclusiveMode(String deviceId) async {
    try {
      final result = await platform.invokeMethod('supportsExclusiveMode', {
        'deviceId': deviceId,
      });

      return result['supported'] as bool? ?? false;
    } catch (e) {
      print('[AudioDevicePlatformWindows] Error checking exclusive mode support: $e');
      return false;
    }
  }

  @override
  Future<bool> enableExclusiveMode(String deviceId, bool enable) async {
    try {
      final result = await platform.invokeMethod('enableExclusiveMode', {
        'deviceId': deviceId,
        'enable': enable,
      });

      return result['success'] as bool? ?? false;
    } on PlatformException catch (e, stackTrace) {
      if (e.code == 'DEVICE_IN_USE') {
        ErrorHandler().logExpectedError(
          'audio_device_exclusive_mode_in_use',
          e,
          stackTrace: stackTrace,
          extras: {
            'code': e.code,
            'deviceId': deviceId,
            'action': enable ? 'enable' : 'disable',
          },
        );
      } else {
        AnalyticsService().captureError(
          e,
          stackTrace,
          context: 'audio_device_platform_exclusive_mode',
          extras: {
            'platform': 'Windows',
            'code': e.code,
            'deviceId': deviceId,
            'enable': enable,
            'message': e.message,
          },
        );
      }
      return false;
    }
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
      print('[AudioDevicePlatformWindows] Error getting format: $e');
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
      print('[AudioDevicePlatformWindows] Error getting metadata: $e');
      return null;
    }
  }
}
