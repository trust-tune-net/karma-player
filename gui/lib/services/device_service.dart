/// Device identity management service.
///
/// Generates and persists a unique device ID (UUID) for API authentication.
/// The device ID is created once on first app launch and stored persistently.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const String _deviceIdKey = 'device_id';
  static final DeviceService _instance = DeviceService._internal();

  factory DeviceService() => _instance;
  DeviceService._internal();

  final Uuid _uuid = const Uuid();
  String? _cachedDeviceId;

  /// Get the device ID, generating one if it doesn't exist.
  ///
  /// Returns the persistent device ID (UUID v4 format).
  /// Caches the ID in memory after first retrieval.
  Future<String> getDeviceId() async {
    // Return cached value if available
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // Try to load from persistent storage
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    // Generate new ID if not found
    if (deviceId == null) {
      deviceId = _uuid.v4();
      await prefs.setString(_deviceIdKey, deviceId);
      print('Generated new device ID: ${deviceId.substring(0, 8)}...');
    } else {
      print('Loaded existing device ID: ${deviceId.substring(0, 8)}...');
    }

    // Cache for future calls
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Check if a device ID has been generated.
  ///
  /// Returns true if device ID exists in storage, false otherwise.
  Future<bool> hasDeviceId() async {
    if (_cachedDeviceId != null) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_deviceIdKey);
  }

  /// Reset the device ID (generate a new one).
  ///
  /// WARNING: This will invalidate the current API key and require
  /// re-authentication. Use with caution.
  Future<String> resetDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final newDeviceId = _uuid.v4();

    await prefs.setString(_deviceIdKey, newDeviceId);
    _cachedDeviceId = newDeviceId;

    print('Reset device ID to: ${newDeviceId.substring(0, 8)}...');
    return newDeviceId;
  }

  /// Clear cached device ID (for testing).
  ///
  /// Does not remove from persistent storage, only clears memory cache.
  void clearCache() {
    _cachedDeviceId = null;
  }

  /// Remove device ID from storage completely.
  ///
  /// This is a destructive operation - use only for testing or uninstall cleanup.
  Future<void> removeDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    _cachedDeviceId = null;
    print('Removed device ID from storage');
  }
}
