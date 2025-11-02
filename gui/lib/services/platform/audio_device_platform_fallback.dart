import 'audio_device_platform.dart';

/// Fallback implementation for platforms that don't support native enumeration
/// Returns empty lists - caller will fall back to media_kit enumeration
class AudioDevicePlatformFallback implements AudioDevicePlatform {
  @override
  bool get supportsNativeEnumeration => false;

  @override
  Future<List<PlatformAudioDevice>> enumerateDevices() async {
    // Return empty list - caller will fall back to media_kit
    print('[AudioDevicePlatformFallback] Native enumeration not supported on this platform');
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
