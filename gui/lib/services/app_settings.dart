import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  static const String defaultSearchApiUrl = 'https://trust-tune-trust-tune-community-api.62ickh.easypanel.host';
  String searchApiUrl = defaultSearchApiUrl;
  String transmissionRpcUrl = 'http://localhost:9091';
  String? customDownloadDir;

  // Statistics
  int totalPlays = 0;
  int totalDownloadedBytes = 0;
  int albumCount = 0;
  Set<int> completedTorrentIds = {}; // Track which torrents we've already counted

  // Health status
  bool apiHealthy = false;
  DateTime? lastHealthCheck;
  int apiResponseTimeMs = 0; // API response time in milliseconds

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    searchApiUrl = prefs.getString('search_api_url') ?? defaultSearchApiUrl;
    transmissionRpcUrl = prefs.getString('transmission_rpc_url') ?? 'http://localhost:9091';
    customDownloadDir = prefs.getString('custom_download_dir');
    totalPlays = prefs.getInt('total_plays') ?? 0;
    totalDownloadedBytes = prefs.getInt('total_downloaded_bytes') ?? 0;
    albumCount = prefs.getInt('album_count') ?? 0;

    // Load completed torrent IDs
    final completedIds = prefs.getStringList('completed_torrent_ids') ?? [];
    completedTorrentIds = completedIds.map((id) {
      try {
        return int.parse(id);
      } catch (e) {
        print('[AppSettings] Invalid torrent ID: $id');
        return null;
      }
    }).whereType<int>().toSet();
  }

  Future<void> saveSearchApiUrl(String url) async {
    searchApiUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('search_api_url', url);
  }

  Future<void> saveTransmissionRpcUrl(String url) async {
    transmissionRpcUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transmission_rpc_url', url);
  }

  Future<void> saveDownloadDir(String dir) async {
    customDownloadDir = dir;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_download_dir', dir);
  }

  Future<void> incrementPlays() async {
    totalPlays++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_plays', totalPlays);
    notifyListeners(); // Notify all listeners that stats changed
  }

  Future<void> addDownloadedBytes(int bytes, int torrentId) async {
    // Only add if we haven't already counted this torrent
    if (!completedTorrentIds.contains(torrentId)) {
      completedTorrentIds.add(torrentId);
      totalDownloadedBytes += bytes;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('total_downloaded_bytes', totalDownloadedBytes);
      // Save completed IDs
      await prefs.setStringList(
        'completed_torrent_ids',
        completedTorrentIds.map((id) => id.toString()).toList(),
      );
      notifyListeners(); // Notify all listeners that download stats changed
    }
  }

  Future<void> updateAlbumCount(int count) async {
    albumCount = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('album_count', albumCount);
    notifyListeners(); // Notify all listeners that library stats changed
  }

  bool get isUsingDefaultApi => searchApiUrl == defaultSearchApiUrl;

  String get displaySearchApiUrl {
    if (isUsingDefaultApi) {
      return '•••••••••••••••••••••••';
    }
    return searchApiUrl;
  }

  String get downloadedGigabytes {
    final gb = totalDownloadedBytes / (1024 * 1024 * 1024);
    return gb.toStringAsFixed(2);
  }

  Future<bool> checkApiHealth() async {
    try {
      final startTime = DateTime.now();
      // Check our API health endpoint
      final response = await http.get(
        Uri.parse('$searchApiUrl/health'),
      ).timeout(const Duration(seconds: 3));
      final endTime = DateTime.now();

      apiResponseTimeMs = endTime.difference(startTime).inMilliseconds;
      apiHealthy = response.statusCode == 200;
      lastHealthCheck = DateTime.now();
      notifyListeners(); // Notify all listeners that connection status changed
      return apiHealthy;
    } catch (e) {
      apiHealthy = false;
      apiResponseTimeMs = 9999; // High value to indicate failure
      lastHealthCheck = DateTime.now();
      notifyListeners(); // Notify all listeners that connection failed
      return false;
    }
  }

  String get connectionQuality {
    if (!apiHealthy) return 'offline';
    if (apiResponseTimeMs < 200) return 'good';
    if (apiResponseTimeMs < 500) return 'medium';
    return 'poor';
  }

  (Color, String) get connectionBadge {
    switch (connectionQuality) {
      case 'good':
        return (const Color(0xFF10B981), 'Good'); // Green
      case 'medium':
        return (const Color(0xFFF59E0B), 'Medium'); // Orange
      case 'poor':
        return (const Color(0xFFEF4444), 'Poor'); // Red
      default:
        return (const Color(0xFF6B7280), 'Offline'); // Gray
    }
  }
}
