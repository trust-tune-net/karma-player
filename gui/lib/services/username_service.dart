import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'device_service.dart';
import 'api_auth_service.dart';

/// Service for fetching and caching Reddit-style usernames.
///
/// Usernames are generated server-side from device_id and cached locally.
/// Format: "Adjective-Noun-Number" (e.g., "Feisty-Sky-6018")
class UsernameService {
  static const String _usernameKey = 'user_username';
  static const String _adjectiveKey = 'user_adjective';
  static const String _nounKey = 'user_noun';
  static const String _numberKey = 'user_number';

  final DeviceService _deviceService;
  final ApiAuthService _apiAuthService;
  final String _apiBaseUrl;

  // Memory cache
  String? _cachedUsername;
  String? _cachedAdjective;
  String? _cachedNoun;
  int? _cachedNumber;

  UsernameService({
    required DeviceService deviceService,
    required ApiAuthService apiAuthService,
    required String apiBaseUrl,
  })  : _deviceService = deviceService,
        _apiAuthService = apiAuthService,
        _apiBaseUrl = apiBaseUrl;

  /// Get the user's username.
  ///
  /// Returns cached value if available, otherwise fetches from API.
  /// Throws exception if API call fails.
  Future<String> getUsername() async {
    // Check memory cache
    if (_cachedUsername != null) {
      return _cachedUsername!;
    }

    // Check persistent storage
    final prefs = await SharedPreferences.getInstance();
    final storedUsername = prefs.getString(_usernameKey);

    if (storedUsername != null) {
      // Load all components from storage
      _cachedUsername = storedUsername;
      _cachedAdjective = prefs.getString(_adjectiveKey);
      _cachedNoun = prefs.getString(_nounKey);
      _cachedNumber = prefs.getInt(_numberKey);

      return _cachedUsername!;
    }

    // Fetch from API
    await _fetchAndCacheUsername();

    if (_cachedUsername == null) {
      throw Exception('Failed to fetch username from API');
    }

    return _cachedUsername!;
  }

  /// Get individual username components.
  ///
  /// Returns (adjective, noun, number) tuple.
  /// Example: ("Feisty", "Sky", 6018)
  Future<(String, String, int)> getUsernameComponents() async {
    // Ensure username is loaded (which loads all components)
    await getUsername();

    if (_cachedAdjective == null || _cachedNoun == null || _cachedNumber == null) {
      throw Exception('Username components not available');
    }

    return (_cachedAdjective!, _cachedNoun!, _cachedNumber!);
  }

  /// Force refresh username from API.
  ///
  /// Clears cache and fetches fresh data from server.
  /// Use this if device_id changes or to verify username hasn't changed.
  Future<String> refreshUsername() async {
    await clearCache();
    await _fetchAndCacheUsername();

    if (_cachedUsername == null) {
      throw Exception('Failed to refresh username from API');
    }

    return _cachedUsername!;
  }

  /// Clear cached username data.
  ///
  /// Call this when user logs out or resets device.
  Future<void> clearCache() async {
    // Clear memory cache
    _cachedUsername = null;
    _cachedAdjective = null;
    _cachedNoun = null;
    _cachedNumber = null;

    // Clear persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_adjectiveKey);
    await prefs.remove(_nounKey);
    await prefs.remove(_numberKey);
  }

  /// Fetch username from API and cache it.
  Future<void> _fetchAndCacheUsername() async {
    try {
      // Get auth headers
      final authHeaders = await _apiAuthService.getAuthHeaders();

      // Call API
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/user/identity'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract username and components
        final username = data['username'] as String;
        final components = data['components'] as Map<String, dynamic>;
        final adjective = components['adjective'] as String;
        final noun = components['noun'] as String;
        final number = components['number'] as int;

        // Cache in memory
        _cachedUsername = username;
        _cachedAdjective = adjective;
        _cachedNoun = noun;
        _cachedNumber = number;

        // Persist to storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_usernameKey, username);
        await prefs.setString(_adjectiveKey, adjective);
        await prefs.setString(_nounKey, noun);
        await prefs.setInt(_numberKey, number);
      } else {
        throw Exception('API returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch username: $e');
    }
  }

  /// Check if username is cached locally.
  Future<bool> isCached() async {
    if (_cachedUsername != null) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_usernameKey);
  }
}
