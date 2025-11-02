import 'dart:io';
import 'package:flutter/services.dart';
import 'audio_device_platform.dart';
import '../analytics_service.dart';
import '../error_handler.dart';

class AudioDevicePlatformMacOS implements AudioDevicePlatform {
  static const platform = MethodChannel('com.trusttune.audio_device');

  @override
  bool get supportsNativeEnumeration => Platform.isMacOS;

  @override
  Future<List<PlatformAudioDevice>> enumerateDevices() async {
    try {
      final List<dynamic> devices = await platform.invokeMethod('enumerateDevices');
      final deviceList = devices
          .map((d) => PlatformAudioDevice.fromMap(Map<String, dynamic>.from(d)))
          .toList();

      print('[AudioDevicePlatformMacOS] Enumerated ${deviceList.length} devices');

      // Log Bluetooth devices specifically
      final bluetoothCount = deviceList.where((d) => d.isBluetooth).length;
      if (bluetoothCount > 0) {
        print('[AudioDevicePlatformMacOS] ✅ Found $bluetoothCount Bluetooth device(s)');
        for (var device in deviceList.where((d) => d.isBluetooth)) {
          print('[AudioDevicePlatformMacOS]   🔵 ${device.name}');
        }
      }

      return deviceList;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] PlatformException enumerating devices: ${e.message}');

      // This is an unexpected error - CoreAudio should always work on macOS
      // Report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_enumerate',
        extras: {
          'platform': 'macOS',
          'code': e.code,
          'message': e.message,
        },
      );
      return [];
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Unexpected error enumerating: $e');

      // Unexpected error - report to GlitchTip
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
      if (device == null) {
        print('[AudioDevicePlatformMacOS] No default device returned');
        return null;
      }

      final platformDevice = PlatformAudioDevice.fromMap(Map<String, dynamic>.from(device));
      print('[AudioDevicePlatformMacOS] Default device: ${platformDevice.name}');
      return platformDevice;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] PlatformException getting default device: ${e.message}');

      // This is unexpected - macOS should always have a default device
      // Report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_default',
        extras: {
          'platform': 'macOS',
          'code': e.code,
          'message': e.message,
        },
      );
      return null;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Unexpected error getting default: $e');

      // Unexpected error - report to GlitchTip
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

      final success = result['success'] as bool? ?? false;
      print('[AudioDevicePlatformMacOS] Device selection: $deviceId -> $success');
      return success;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] PlatformException setting device: ${e.message}');

      // Check if this is an expected error
      if (e.code == 'DEVICE_IN_USE' || e.code == 'DEVICE_DISCONNECTED') {
        // Expected error - device unplugged or in use
        // Log only, don't send to GlitchTip
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
        // Unexpected error - permission denied or API failure
        // Report to GlitchTip
        AnalyticsService().captureError(
          e,
          stackTrace,
          context: 'audio_device_platform_set_device',
          extras: {
            'platform': 'macOS',
            'code': e.code,
            'deviceId': deviceId,
            'message': e.message,
          },
        );
      }
      return false;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Unexpected error setting device: $e');

      // Unexpected error - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_set_device_unknown',
        extras: {
          'platform': 'macOS',
          'deviceId': deviceId,
        },
      );
      return false;
    }
  }

  // MARK: - Exclusive Mode Support (Phase 2)

  @override
  Future<bool> supportsExclusiveMode(String deviceId) async {
    try {
      final result = await platform.invokeMethod('supportsExclusiveMode', {
        'deviceId': deviceId,
      });

      final supported = result['supported'] as bool? ?? false;
      final mode = result['mode'] as String? ?? 'unknown';

      if (supported) {
        print('[AudioDevicePlatformMacOS] Device $deviceId supports exclusive mode ($mode)');
      } else {
        print('[AudioDevicePlatformMacOS] Device $deviceId does not support exclusive mode');
      }

      return supported;
    } catch (e) {
      print('[AudioDevicePlatformMacOS] Error checking exclusive mode support: $e');
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

      final success = result['success'] as bool? ?? false;
      final modeStr = enable ? 'enabled' : 'disabled';

      if (success) {
        print('[AudioDevicePlatformMacOS] ✓ Exclusive mode $modeStr for device $deviceId');
      } else {
        print('[AudioDevicePlatformMacOS] ✗ Failed to ${enable ? 'enable' : 'disable'} exclusive mode');
      }

      return success;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] PlatformException: ${e.code} - ${e.message}');

      // Check for expected errors
      if (e.code == 'DEVICE_IN_USE') {
        // Expected error - device is being used exclusively by another app
        // Log only, don't send to GlitchTip
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
        // Unexpected error - report to GlitchTip
        AnalyticsService().captureError(
          e,
          stackTrace,
          context: 'audio_device_platform_exclusive_mode',
          extras: {
            'platform': 'macOS',
            'code': e.code,
            'deviceId': deviceId,
            'enable': enable,
            'message': e.message,
          },
        );
      }

      return false;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Unexpected error setting exclusive mode: $e');

      // Unexpected error - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_exclusive_mode_unknown',
        extras: {
          'platform': 'macOS',
          'deviceId': deviceId,
          'enable': enable,
        },
      );

      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getDeviceFormat(String deviceId) async {
    try {
      final result = await platform.invokeMethod('getDeviceFormat', {
        'deviceId': deviceId,
      });

      if (result == null) {
        print('[AudioDevicePlatformMacOS] No format info for device $deviceId');
        return null;
      }

      final format = Map<String, dynamic>.from(result);
      final sampleRate = format['nominalSampleRate'] ?? format['sampleRate'];
      final bitDepth = format['bitDepth'];
      final channels = format['channels'];

      print('[AudioDevicePlatformMacOS] Device format: ${sampleRate}Hz, ${bitDepth}bit, ${channels}ch');

      return format;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] PlatformException getting format: ${e.message}');

      // This could be unexpected - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_format',
        extras: {
          'platform': 'macOS',
          'code': e.code,
          'deviceId': deviceId,
        },
      );

      return null;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Unexpected error getting format: $e');

      // Unexpected error - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_format_unknown',
        extras: {
          'platform': 'macOS',
          'deviceId': deviceId,
        },
      );

      return null;
    }
  }
}
