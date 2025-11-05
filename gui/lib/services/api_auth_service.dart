// API authentication service.
//
// Generates HMAC-based API keys for authenticating with the TrustTune API.
// Uses the same HMAC-SHA256 algorithm as the backend to create deterministic
// but unpredictable API keys based on device ID + secret salt.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'device_service.dart';

class ApiAuthService {
  static final ApiAuthService _instance = ApiAuthService._internal();

  factory ApiAuthService() => _instance;
  ApiAuthService._internal();

  final DeviceService _deviceService = DeviceService();

  // TEMPORARY: Hardcoded salt for Phase 0
  // TODO Phase 1: Fetch salt from bootstrap service or environment config
  // This salt MUST match the API_SECRET_SALT on the server
  // For production, this should be fetched from a secure bootstrap endpoint
  // or compiled into the app as an environment variable
  static const String _temporarySalt = '_gsPybnjxhrmSnWTZPeBzZpJcLuM4nVX6Z2ZZ9vxxio';

  /// Generate an HMAC-SHA256 API key for the current device.
  ///
  /// Uses the device ID and a secret salt to create a deterministic key.
  /// The same device ID + salt will always produce the same key.
  ///
  /// Returns a 64-character hexadecimal string.
  Future<String> generateApiKey() async {
    final deviceId = await _deviceService.getDeviceId();
    return _generateHmacKey(deviceId, _temporarySalt);
  }

  /// Generate HMAC-SHA256 key from device ID and salt.
  ///
  /// This method matches the Python backend implementation:
  /// ```python
  /// hmac.new(salt.encode('utf-8'), device_id.encode('utf-8'), hashlib.sha256).hexdigest()
  /// ```
  String _generateHmacKey(String deviceId, String salt) {
    // Convert salt and device ID to bytes
    final saltBytes = utf8.encode(salt);
    final deviceIdBytes = utf8.encode(deviceId);

    // Create HMAC-SHA256 hash
    final hmacSha256 = Hmac(sha256, saltBytes);
    final digest = hmacSha256.convert(deviceIdBytes);

    // Return as hexadecimal string (64 characters)
    return digest.toString();
  }

  /// Get authentication headers for API requests.
  ///
  /// Returns a map of headers to add to HTTP requests:
  /// - X-Device-ID: The unique device identifier
  /// - X-API-Key: The HMAC-based API key
  Future<Map<String, String>> getAuthHeaders() async {
    final deviceId = await _deviceService.getDeviceId();
    final apiKey = await generateApiKey();

    return {
      'X-Device-ID': deviceId,
      'X-API-Key': apiKey,
    };
  }

  /// Get authentication data for WebSocket connections.
  ///
  /// Returns a map to include in the first WebSocket message:
  /// ```json
  /// {
  ///   "auth": {
  ///     "device_id": "...",
  ///     "api_key": "..."
  ///   }
  /// }
  /// ```
  Future<Map<String, String>> getWebSocketAuth() async {
    final deviceId = await _deviceService.getDeviceId();
    final apiKey = await generateApiKey();

    return {
      'device_id': deviceId,
      'api_key': apiKey,
    };
  }

  /// Validate that the salt is configured.
  ///
  /// Returns true if a salt is set (not the placeholder).
  /// In production, this should validate that the salt was properly
  /// configured during build or fetched from bootstrap service.
  bool isSaltConfigured() {
    return _temporarySalt != 'REPLACE_WITH_YOUR_SECRET_SALT';
  }

  /// For testing: Generate API key with custom salt.
  ///
  /// This is exposed for testing purposes to verify key generation
  /// matches the backend implementation.
  String generateTestKey(String deviceId, String salt) {
    return _generateHmacKey(deviceId, salt);
  }
}
