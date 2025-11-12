import 'audio_device_platform.dart';

/// Fallback implementation for platforms that don't support native enumeration
/// Returns empty lists - caller will fall back to media_kit enumeration
class AudioDevicePlatformFallback implements AudioDevicePlatform {
  @override
  bool get supportsNativeEnumeration => false;

  @override
  bool get supportsAirPlayRouting => false;

  @override
  bool get supportsCastRouting => false;

  @override
  Future<List<PlatformAudioDevice>> enumerateDevices() async {
    // Return empty list - caller will fall back to media_kit
    print('[AudioDevicePlatformFallback] Native enumeration not supported on this platform');
    return [];
  }

  @override
  Future<bool> showAirPlayPicker() async {
    return false;
  }

  @override
  Future<bool> showCastPicker() async {
    return false;
  }

  @override
  Future<bool> openSystemSoundSettings() async {
    return false;
  }

  @override
  Future<PlatformAudioDevice?> getDefaultDevice() async {
    return null;
  }

  @override
  Future<bool> setAudioDevice(String deviceId) async {
    return false;
  }

  // Exclusive Mode Support - Not supported on this platform
  @override
  Future<ExclusiveModeCapability> getExclusiveModeCapability(String deviceId) async {
    return const ExclusiveModeCapability(
      supported: false,
      reason: 'Exclusive mode is not exposed by this platform adapter.',
    );
  }

  @override
  Future<bool> enableExclusiveMode(String deviceId, bool enable) async {
    return false; // No exclusive mode support on non-macOS platforms yet
  }

  @override
  Future<Map<String, dynamic>?> getDeviceFormat(String deviceId) async {
    return null; // No format info available on non-macOS platforms yet
  }

  // Phase 3 - Advanced Device Metadata
  @override
  Future<MetadataFetchResult> getDeviceMetadata(String deviceId) async {
    return const MetadataFetchResult(
      metadata: null,
      reason: 'Advanced metadata is not exposed by this platform adapter.',
    );
  }
}
