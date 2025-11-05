import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for a connected mobile device
class ConnectedMobileDevice {
  final String id;
  final String name;
  final String ipAddress;
  final DateTime connectedAt;

  ConnectedMobileDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.connectedAt,
  });
}

/// Service for managing mobile app discovery and connections
class MobileDiscoveryService extends ChangeNotifier {
  static final MobileDiscoveryService _instance = MobileDiscoveryService._internal();
  factory MobileDiscoveryService() => _instance;
  MobileDiscoveryService._internal();

  bool _isEnabled = false;
  bool _isInitialized = false;
  String _deviceName = '';
  String _ipAddress = '';
  final int _port = 54847; // High port for mobile API (avoid conflicts)
  final List<ConnectedMobileDevice> _connectedDevices = [];

  HttpServer? _server;
  Timer? _announcementTimer;

  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;
  String get deviceName => _deviceName;
  String get ipAddress => _ipAddress;
  int get port => _port;
  List<ConnectedMobileDevice> get connectedDevices => List.unmodifiable(_connectedDevices);

  /// Get connection URL for QR code
  String get connectionUrl {
    if (_ipAddress.isEmpty) {
      return '';
    }
    return 'karmaplayer://$_ipAddress:$_port';
  }

  /// Get connection info as JSON for QR code
  String get connectionInfoJson {
    return jsonEncode({
      'type': 'karmaplayer_desktop',
      'version': '1.0',
      'name': _deviceName,
      'ip': _ipAddress,
      'port': _port,
      'capabilities': ['playback', 'library', 'search'],
    });
  }

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load enabled state from preferences
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('mobile_discovery_enabled') ?? false;

    // Get device name (hostname or default)
    try {
      _deviceName = Platform.localHostname;
    } catch (e) {
      _deviceName = 'KarmaPlayer Desktop';
    }

    // Get local IP address
    await _updateIpAddress();

    _isInitialized = true;
    notifyListeners();

    // Auto-start server if it was previously enabled
    // This ensures mobile apps can connect without requiring user to toggle
    if (_isEnabled) {
      print('[MobileDiscovery] Auto-starting server (was previously enabled)');
      await _startDiscovery();
    }
  }

  /// Update local IP address
  Future<void> _updateIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Prefer non-loopback addresses
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            _ipAddress = addr.address;
            return;
          }
        }
      }

      // Fallback to localhost if no other address found
      _ipAddress = '127.0.0.1';
    } catch (e) {
      print('[MobileDiscovery] Error getting IP address: $e');
      _ipAddress = '127.0.0.1';
    }
  }

  /// Enable mobile discovery
  Future<void> enable() async {
    if (_isEnabled) return;

    _isEnabled = true;

    // Save state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mobile_discovery_enabled', true);

    await _startDiscovery();
    notifyListeners();
  }

  /// Disable mobile discovery
  Future<void> disable() async {
    if (!_isEnabled) return;

    _isEnabled = false;

    // Save state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mobile_discovery_enabled', false);

    await _stopDiscovery();
    notifyListeners();
  }

  /// Toggle mobile discovery
  Future<void> toggle() async {
    if (_isEnabled) {
      await disable();
    } else {
      await enable();
    }
  }

  /// Start discovery service
  Future<void> _startDiscovery() async {
    if (_server != null) return;

    try {
      // Start simple HTTP server for mobile connections
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      print('[MobileDiscovery] Started server on port $_port');

      // Handle incoming connections
      _server!.listen((HttpRequest request) {
        _handleRequest(request);
      }, onError: (error) {
        print('[MobileDiscovery] Server error: $error');
      });

      // TODO: Start mDNS broadcasting
      // This would require the multicast_dns package and proper implementation
      // For now, we'll use QR code for initial connection

      print('[MobileDiscovery] Discovery enabled: $connectionInfoJson');
    } catch (e) {
      print('[MobileDiscovery] Error starting discovery: $e');
      _server = null;
    }
  }

  /// Stop discovery service
  Future<void> _stopDiscovery() async {
    // Stop announcement timer
    _announcementTimer?.cancel();
    _announcementTimer = null;

    // Close HTTP server
    await _server?.close();
    _server = null;

    // Clear connected devices
    _connectedDevices.clear();

    print('[MobileDiscovery] Discovery disabled');
  }

  /// Handle incoming HTTP request from mobile app
  void _handleRequest(HttpRequest request) {
    // CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response
        ..statusCode = HttpStatus.ok
        ..close();
      return;
    }

    // Handle different endpoints
    final path = request.uri.path;

    switch (path) {
      case '/info':
        _handleInfoRequest(request);
        break;
      case '/connect':
        _handleConnectRequest(request);
        break;
      case '/ping':
        _handlePingRequest(request);
        break;
      default:
        request.response
          ..statusCode = HttpStatus.notFound
          ..write(jsonEncode({'error': 'Not found'}))
          ..close();
    }
  }

  /// Handle /info endpoint - returns server info
  void _handleInfoRequest(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(connectionInfoJson)
      ..close();
  }

  /// Handle /connect endpoint - mobile app initial connection
  Future<void> _handleConnectRequest(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body);

      final deviceId = data['device_id'] as String?;
      final deviceName = data['device_name'] as String?;
      final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';

      if (deviceId != null && deviceName != null) {
        // Add to connected devices
        _connectedDevices.removeWhere((d) => d.id == deviceId);
        _connectedDevices.add(ConnectedMobileDevice(
          id: deviceId,
          name: deviceName,
          ipAddress: clientIp,
          connectedAt: DateTime.now(),
        ));

        notifyListeners();

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'success': true,
            'message': 'Connected successfully',
            'server_name': _deviceName,
          }))
          ..close();

        print('[MobileDiscovery] Device connected: $deviceName ($clientIp)');
      } else {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write(jsonEncode({'error': 'Invalid request'}))
          ..close();
      }
    } catch (e) {
      print('[MobileDiscovery] Error handling connect request: $e');
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write(jsonEncode({'error': 'Internal server error'}))
        ..close();
    }
  }

  /// Handle /ping endpoint - keep-alive from mobile
  void _handlePingRequest(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}))
      ..close();
  }

  /// Remove a connected device
  void removeDevice(String deviceId) {
    _connectedDevices.removeWhere((d) => d.id == deviceId);
    notifyListeners();
  }

  /// Dispose service
  @override
  void dispose() {
    _stopDiscovery();
    super.dispose();
  }
}
