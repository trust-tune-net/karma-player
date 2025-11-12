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
  bool get supportsAirPlayRouting => Platform.isMacOS;

  @override
  bool get supportsCastRouting => false;

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

  @override
  Future<bool> showAirPlayPicker() async {
    try {
      await platform.invokeMethod('showAirPlayPicker');
      return true;
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Failed to show AirPlay picker: ${e.message}');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_airplay_picker',
        extras: {
          'platform': 'macOS',
          'code': e.code,
          'message': e.message,
        },
      );
      return false;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Unexpected AirPlay picker error: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_airplay_picker_unknown',
        extras: {'platform': 'macOS'},
      );
      return false;
    }
  }

  @override
  Future<bool> showCastPicker() async {
    // macOS does not provide a native Google Cast picker.
    return false;
  }

  @override
  Future<bool> openSystemSoundSettings() async {
    try {
      final result = await Process.run(
        'open',
        ['x-apple.systempreferences:com.apple.preference.sound?output'],
      );
      final success = result.exitCode == 0;
      if (!success) {
        print('[AudioDevicePlatformMacOS] Failed to open Sound settings: ${result.stderr}');
      }
      return success;
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Error opening Sound settings: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_open_sound_settings',
        extras: {'platform': 'macOS'},
      );
      return false;
    }
  }

  // MARK: - Exclusive Mode Support (Phase 2)

  @override
  Future<ExclusiveModeCapability> getExclusiveModeCapability(String deviceId) async {
    try {
      final result = await platform.invokeMethod('supportsExclusiveMode', {
        'deviceId': deviceId,
      });

      if (result is Map) {
        final supported = result['supported'] as bool? ?? false;
        final mode = result['mode'] as String? ?? 'unknown';
        final reason = result['reason'] as String?;

        if (supported) {
          print('[AudioDevicePlatformMacOS] Device $deviceId supports exclusive mode ($mode)');
        } else {
          print('[AudioDevicePlatformMacOS] Device $deviceId does not support exclusive mode');
        }

        return ExclusiveModeCapability(
          supported: supported,
          reason: supported
              ? null
              : reason ??
                  'macOS reported that this device cannot enter exclusive (hog) mode. Try selecting a different output '
                      'or update the device driver.',
        );
      }

      final supported = (result as bool?) ?? false;
      return ExclusiveModeCapability(
        supported: supported,
        reason: supported
            ? null
            : 'macOS reported that this device cannot enter exclusive (hog) mode.',
      );
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] PlatformException checking exclusive mode support: ${e.message}');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_exclusive_capability',
        extras: {
          'platform': 'macOS',
          'code': e.code,
          'message': e.message,
          'deviceId': deviceId,
        },
      );
      return ExclusiveModeCapability(
        supported: false,
        reason: e.message ?? e.code,
      );
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Unexpected error checking exclusive mode support: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_exclusive_capability_unknown',
        extras: {'platform': 'macOS', 'deviceId': deviceId},
      );
      return const ExclusiveModeCapability(
        supported: false,
        reason: 'Unexpected error while checking exclusive mode support.',
      );
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

  // MARK: - Phase 3: Advanced Device Metadata

  @override
  Future<MetadataFetchResult> getDeviceMetadata(String deviceId) async {
    try {
      final result = await platform.invokeMethod('getDeviceMetadata', {
        'deviceId': deviceId,
      });

      if (result == null) {
        print('[AudioDevicePlatformMacOS] No metadata for device $deviceId');
        return const MetadataFetchResult(
          metadata: null,
          reason: 'macOS CoreAudio did not return metadata for this device.',
        );
      }

      // Deep convert all nested maps to Map<String, dynamic>
      final metadata = _deepConvertMap(result as Map);

      // Log interesting metadata
      if (metadata.containsKey('chipset')) {
        print('[AudioDevicePlatformMacOS] USB DAC chipset: ${metadata['chipset']}');
      }
      if (metadata.containsKey('bluetoothCodec')) {
        print('[AudioDevicePlatformMacOS] Bluetooth codec: ${metadata['bluetoothCodec']}');
      }
      if (metadata.containsKey('supportedSampleRates')) {
        final rates = (metadata['supportedSampleRates'] as List).cast<double>();
        print('[AudioDevicePlatformMacOS] Supported sample rates: ${rates.join(', ')} Hz');
      }

      return MetadataFetchResult(metadata: metadata);
    } on PlatformException catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] PlatformException getting metadata: ${e.message}');

      // This could be unexpected - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_metadata',
        extras: {
          'platform': 'macOS',
          'code': e.code,
          'deviceId': deviceId,
        },
      );

      return MetadataFetchResult(
        metadata: null,
        reason: e.message ?? 'Failed to fetch metadata (platform exception).',
      );
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Unexpected error getting metadata: $e');

      // Unexpected error - report to GlitchTip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'audio_device_platform_get_metadata_unknown',
        extras: {
          'platform': 'macOS',
          'deviceId': deviceId,
        },
      );

      return const MetadataFetchResult(
        metadata: null,
        reason: 'Unexpected error while fetching device metadata.',
      );
    }
  }

  /// Deep convert Map<Object?, Object?> to Map<String, dynamic>
  /// This is needed because Swift's [String: Any] comes through as Map<Object?, Object?>
  Map<String, dynamic> _deepConvertMap(Map map) {
    final result = <String, dynamic>{};

    try {
      map.forEach((key, value) {
        final keyStr = key.toString();

        if (value == null) {
          result[keyStr] = null;
        } else if (value is Map) {
          // Recursively convert nested maps
          result[keyStr] = _deepConvertMap(value);
        } else if (value is List) {
          // Convert lists (might contain maps)
          result[keyStr] = value.map((item) {
            if (item is Map) {
              return _deepConvertMap(item);
            }
            return item;
          }).toList();
        } else {
          result[keyStr] = value;
        }
      });
    } catch (e, stackTrace) {
      print('[AudioDevicePlatformMacOS] Error in _deepConvertMap: $e');
      print('[AudioDevicePlatformMacOS] Stack trace: $stackTrace');
    }

    return result;
  }
}
