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
}
