import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/torrent.dart';
import 'analytics_service.dart';

/// Transmission RPC client for torrent management
class TransmissionClient {
  final String baseUrl;
  String? _sessionId;

  TransmissionClient({this.baseUrl = 'http://localhost:9091'});

  /// Make an RPC request to transmission daemon
  Future<Map<String, dynamic>> _rpcRequest(
    String method, {
    Map<String, dynamic>? arguments,
  }) async {
    final url = Uri.parse('$baseUrl/transmission/rpc');

    // Build request body
    final body = {
      'method': method,
      if (arguments != null) 'arguments': arguments,
    };

    // Make request with session ID if available
    final headers = {
      'Content-Type': 'application/json',
      if (_sessionId != null) 'X-Transmission-Session-Id': _sessionId!,
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      // Handle CSRF token (409 response) - expected behavior, don't report
      if (response.statusCode == 409) {
        _sessionId = response.headers['x-transmission-session-id'];
        if (_sessionId == null) {
          // This is a real error - failed to get session ID from expected 409 response
          final error = Exception('Failed to get session ID from 409 response');
          AnalyticsService().captureError(
            error,
            StackTrace.current,
            context: 'transmission_session_id_missing',
            extras: {
              'method': method,
              'base_url': baseUrl,
              'has_session_id': _sessionId != null,
            },
          );
          throw error;
        }
        // Retry with new session ID
        return _rpcRequest(method, arguments: arguments);
      }

      // Report non-200/409 status codes as errors
      if (response.statusCode != 200) {
        final error = Exception('RPC request failed: ${response.statusCode} ${response.body}');
        AnalyticsService().captureError(
          error,
          StackTrace.current,
          context: 'transmission_rpc_http_error',
          extras: {
            'method': method,
            'base_url': baseUrl,
            'status_code': response.statusCode,
            'has_session_id': _sessionId != null,
          },
        );
        throw error;
      }

      // Parse JSON response
      late Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e, stackTrace) {
        // JSON parsing failure
        final error = Exception('Failed to parse RPC response: $e');
        AnalyticsService().captureError(
          error,
          stackTrace,
          context: 'transmission_rpc_json_parse_error',
          extras: {
            'method': method,
            'base_url': baseUrl,
            'response_body_preview': response.body.substring(0, response.body.length > 200 ? 200 : response.body.length),
          },
        );
        throw error;
      }

      // Check if RPC returned an error
      if (data['result'] != 'success') {
        final error = Exception('RPC error: ${data['result']}');
        AnalyticsService().captureError(
          error,
          StackTrace.current,
          context: 'transmission_rpc_error',
          extras: {
            'method': method,
            'base_url': baseUrl,
            'rpc_result': data['result'],
            'has_session_id': _sessionId != null,
          },
        );
        throw error;
      }

      return data['arguments'] as Map<String, dynamic>? ?? {};
    } on http.ClientException catch (e, stackTrace) {
      // Catch HTTP exceptions (connection refused, timeouts, network errors)
      // Don't report connection refused errors - they're expected when daemon isn't running
      final errorStr = e.toString();
      final isConnectionError = errorStr.contains('Connection refused') ||
                                errorStr.contains('SocketException') ||
                                errorStr.contains('Failed to connect');
      
      if (!isConnectionError) {
        // Report unexpected network errors only
        AnalyticsService().captureError(
          e,
          stackTrace,
          context: 'transmission_rpc_network_error',
          extras: {
            'method': method,
            'base_url': baseUrl,
            'has_session_id': _sessionId != null,
          },
        );
      }
      rethrow;
    }
  }

  /// Get session information
  Future<Map<String, dynamic>> getSession() async {
    return _rpcRequest('session-get');
  }

  /// Add a torrent by magnet link or URL
  Future<int> addTorrent({
    required String magnetLink,
    String? downloadDir,
  }) async {
    final arguments = {
      'filename': magnetLink,
      if (downloadDir != null) 'download-dir': downloadDir,
    };

    final result = await _rpcRequest('torrent-add', arguments: arguments);

    // Check if torrent was added or already exists
    final torrentAdded = result['torrent-added'] as Map<String, dynamic>?;
    final torrentDuplicate = result['torrent-duplicate'] as Map<String, dynamic>?;

    final torrentInfo = torrentAdded ?? torrentDuplicate;
    if (torrentInfo == null) {
      throw Exception('Failed to add torrent: no torrent info returned');
    }

    return torrentInfo['id'] as int;
  }

  /// Get list of all torrents
  Future<List<Torrent>> getTorrents({List<int>? ids}) async {
    final arguments = {
      'fields': [
        'id',
        'name',
        'percentDone',
        'totalSize',
        'downloadedEver',
        'rateDownload',
        'rateUpload',
        'eta',
        'status',
        'files',
      ],
      if (ids != null && ids.isNotEmpty) 'ids': ids,
    };

    final result = await _rpcRequest('torrent-get', arguments: arguments);

    final torrents = result['torrents'] as List<dynamic>? ?? [];
    return torrents
        .map((t) => Torrent.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Get a single torrent by ID
  Future<Torrent?> getTorrent(int id) async {
    final torrents = await getTorrents(ids: [id]);
    return torrents.isEmpty ? null : torrents.first;
  }

  /// Remove torrents
  Future<void> removeTorrents({
    required List<int> ids,
    bool deleteData = false,
  }) async {
    await _rpcRequest('torrent-remove', arguments: {
      'ids': ids,
      'delete-local-data': deleteData,
    });
  }

  /// Start torrents
  Future<void> startTorrents({required List<int> ids}) async {
    await _rpcRequest('torrent-start', arguments: {'ids': ids});
  }

  /// Stop torrents
  Future<void> stopTorrents({required List<int> ids}) async {
    await _rpcRequest('torrent-stop', arguments: {'ids': ids});
  }

  /// Set torrent location
  Future<void> setTorrentLocation({
    required List<int> ids,
    required String location,
    bool move = false,
  }) async {
    await _rpcRequest('torrent-set-location', arguments: {
      'ids': ids,
      'location': location,
      'move': move,
    });
  }

  /// Get session statistics
  Future<Map<String, dynamic>> getStats() async {
    return _rpcRequest('session-stats');
  }

  /// Test connection to transmission daemon
  Future<bool> testConnection() async {
    try {
      await getSession();
      return true;
    } catch (e) {
      return false;
    }
  }
}
