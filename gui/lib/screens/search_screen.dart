import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/torrent.dart' as torrent_model;
import '../models/song.dart';
import '../services/transmission_client.dart';
import '../services/playback_service.dart';
import '../services/youtube_download_service.dart';
import '../services/analytics_service.dart';
import '../services/api_auth_service.dart';
import '../services/device_service.dart';
import '../services/search_service_grpc.dart';
import '../services/audio_quality_verification_service.dart';
import '../proto/search.pb.dart' as pb_search;
import '../widgets/youtube_download_progress_dialog.dart';
import '../widgets/diagnostics_dialog.dart';
import '../main.dart';

enum SourceFilter { all, torrents, streaming }

class SearchScreen extends StatefulWidget {
  final void Function(Song song, {List<Song>? queue, bool? isShuffled})? onSongTap;
  final VoidCallback? onLibraryRefresh;

  const SearchScreen({super.key, this.onSongTap, this.onLibraryRefresh});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  // Services
  final YouTubeDownloadService _youtubeDownloadService = YouTubeDownloadService();
  final ApiAuthService _apiAuthService = ApiAuthService();
  final DeviceService _deviceService = DeviceService();
  final TextEditingController _searchController = TextEditingController();
  WebSocketChannel? _channel;
  SearchServiceGrpc? _grpcService;

  String _statusMessage = 'Enter a search query';
  int _progress = 0;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _filteredResults = [];
  List<Map<String, dynamic>> _streamingResults = [];
  List<Map<String, dynamic>> _torrentResults = [];
  bool _isSearching = false;
  bool _streamingLoading = false;
  bool _torrentLoading = false;
  bool _useGrpc = true;  // Feature flag: try gRPC first, fallback to WebSocket/HTTP
  bool _useWebSocket = true;  // Feature flag: false = HTTP, true = WebSocket (when gRPC fails)
  SourceFilter _sourceFilter = SourceFilter.all;

  // Quality and source toggles
  bool _reorderByQuality = true;  // Default: ON - sort results by quality score
  bool _showTorrents = true;      // Show torrent results
  bool _showYouTube = true;        // Show YouTube/streaming results

  // Pagination state
  final ScrollController _scrollController = ScrollController();
  int _currentOffset = 0;
  bool _isLoadingMore = false;
  bool _hasMoreResults = true;
  int _totalFound = 0;

  @override
  bool get wantKeepAlive => true;

  /// Get API URL with 0.0.0.0 fixed to 127.0.0.1 (0.0.0.0 is server-only)
  String get _clientApiUrl {
    return appSettings.searchApiUrl.replaceFirst('0.0.0.0', '127.0.0.1');
  }

  @override
  void initState() {
    super.initState();
    // No longer initialize gRPC here - do it dynamically in _searchGrpc()
    _loadFilterPreference();
    _verifyYtDlp();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final pixels = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final threshold = maxScroll * 0.8;

    print('[SCROLL] pixels: $pixels, max: $maxScroll, threshold: $threshold');
    print('[SCROLL] isLoadingMore: $_isLoadingMore, hasMore: $_hasMoreResults, isSearching: $_isSearching');

    if (pixels >= threshold) {
      print('[SCROLL] ✓ Reached 80% threshold!');
      if (!_isLoadingMore && _hasMoreResults && !_isSearching) {
        print('[SCROLL] ✓ Conditions met, loading more...');
        _loadMoreResults();
      } else {
        print('[SCROLL] ✗ Conditions not met: loading=$_isLoadingMore, hasMore=$_hasMoreResults, searching=$_isSearching');
      }
    }
  }

  void _loadMoreResults() async {
    if (_isLoadingMore || !_hasMoreResults || _searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoadingMore = true;
      _currentOffset += 20; // Move to next page
    });

    // Perform another search with new offset using the same method as initial search
    if (_useGrpc) {
      _searchGrpc();
    } else if (_useWebSocket) {
      _searchWebSocket();
    } else {
      _searchHTTP();
    }
  }

  /// Verify yt-dlp binary is available and working
  void _verifyYtDlp() async {
    // Run verification in background, don't block UI
    await _youtubeDownloadService.verifyYtDlp();
  }

  Future<void> _openDiagnostics() async {
    await showDialog(
      context: context,
      builder: (context) => DiagnosticsDialog(
        daemonManager: daemonManager,
        appSettings: appSettings,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _channel?.sink.close();
    _grpcService?.close();
    _youtubeDownloadService.dispose();
    super.dispose();
  }

  Future<void> _loadFilterPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final filterValue = prefs.getString('source_filter') ?? 'all';
    setState(() {
      _sourceFilter = SourceFilter.values.firstWhere(
        (e) => e.name == filterValue,
        orElse: () => SourceFilter.all,
      );
    });
  }

  Future<void> _saveFilterPreference(SourceFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('source_filter', filter.name);
  }

  void _applyFilter() {
    setState(() {
      // Start with all results
      List<Map<String, dynamic>> filtered = _results;

      // Apply old filter chip logic (All/Torrents/Streaming)
      switch (_sourceFilter) {
        case SourceFilter.all:
          filtered = _results;
          break;
        case SourceFilter.torrents:
          filtered = _results.where((result) {
            final source = result['source'] ?? result['torrent'];
            final sourceType = source['source_type'] ?? 'torrent';
            return sourceType == 'torrent';
          }).toList();
          break;
        case SourceFilter.streaming:
          filtered = _results.where((result) {
            final source = result['source'] ?? result['torrent'];
            final sourceType = source['source_type'] ?? 'torrent';
            return sourceType == 'youtube' || sourceType == 'piped';
          }).toList();
          break;
      }

      // Apply new checkbox toggles (Show Torrents / Show YouTube)
      filtered = filtered.where((result) {
        final source = result['source'] ?? result['torrent'];
        final sourceType = source['source_type'] ?? 'torrent';
        final isTorrent = sourceType == 'torrent';
        final isStreaming = sourceType == 'youtube' || sourceType == 'piped' || sourceType == 'invidious';

        // Include result based on toggles
        if (isTorrent && !_showTorrents) return false;
        if (isStreaming && !_showYouTube) return false;
        return true;
      }).toList();

      // Apply quality sorting if toggle is ON
      if (_reorderByQuality) {
        filtered.sort((a, b) {
          final aScore = (a['source'] ?? a['torrent'])['quality_score'] ?? 0.0;
          final bScore = (b['source'] ?? b['torrent'])['quality_score'] ?? 0.0;
          return bScore.compareTo(aScore);  // Descending order (highest first)
        });
      }

      _filteredResults = filtered;
    });
  }

  Future<List<Map<String, dynamic>>> _searchStreaming() async {
    try {
      // Get authentication headers
      final authHeaders = await _apiAuthService.getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_clientApiUrl/api/search/streaming'),
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: json.encode({
          'query': _searchController.text,
          'format_filter': null,
          'min_seeders': 1,
          'limit': 20,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Streaming search error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _searchTorrents() async {
    try {
      // Get authentication headers
      final authHeaders = await _apiAuthService.getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_clientApiUrl/api/search/torrents'),
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: json.encode({
          'query': _searchController.text,
          'format_filter': null,
          'min_seeders': 1,
          'limit': 20,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Torrent search error: $e');
    }
    return [];
  }

  void _searchGrpc() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _streamingLoading = true;
      _torrentLoading = true;
      _progress = 0;
      _statusMessage = 'Connecting via gRPC...';

      if (_currentOffset == 0) {
        _results = [];
        _streamingResults = [];
        _torrentResults = [];
        _hasMoreResults = true;
        _totalFound = 0;
      }
    });

    try {
      // Initialize gRPC service dynamically from current settings (like WebSocket does)
      // Close old service if exists
      _grpcService?.close();

      // Parse host and port from URL (using _clientApiUrl to fix 0.0.0.0)
      String apiUrl = _clientApiUrl;

      // Add scheme if missing for Uri.parse to work
      if (!apiUrl.startsWith('http://') && !apiUrl.startsWith('https://')) {
        apiUrl = 'http://$apiUrl';
      }

      final uri = Uri.parse(apiUrl);
      final host = uri.host.isNotEmpty ? uri.host : 'localhost';
      final port = uri.hasPort ? uri.port : 50051;  // Default to 50051 if no port specified
      final useSecure = port == 443 || uri.scheme == 'https';  // Use secure connection for port 443 or https://

      print('[gRPC] Connecting to: $host:$port (secure: $useSecure)');
      _grpcService = SearchServiceGrpc(
        authService: _apiAuthService,
        deviceService: _deviceService,
        host: host,
        port: port,
        useSecure: useSecure,
      );

      // Execute 2 parallel gRPC searches - one for streaming, one for torrents
      final streamingStream = _grpcService!.search(
        query: _searchController.text,
        minSeeders: 1,
        limit: 10,
        offset: _currentOffset,
        sourceTypeFilter: pb_search.SourceTypeFilter.SOURCE_TYPE_FILTER_STREAMING,
      );

      final torrentStream = _grpcService!.search(
        query: _searchController.text,
        minSeeders: 1,
        limit: 10,
        offset: _currentOffset,
        sourceTypeFilter: pb_search.SourceTypeFilter.SOURCE_TYPE_FILTER_TORRENT,
      );

      // Process both streams concurrently
      await Future.wait([
        _processSearchStream(streamingStream, 'streaming'),
        _processSearchStream(torrentStream, 'torrent'),
      ]);

      // Finalize search after both complete
      setState(() {
        _streamingLoading = false;
        _torrentLoading = false;
        _isSearching = false;
        _isLoadingMore = false;
        _progress = 100;
        _applyFilter();
        _statusMessage = 'Found ${_streamingResults.length} streaming, ${_torrentResults.length} torrents';
      });

    } catch (e) {
      print('[gRPC] Search failed: $e');
      setState(() {
        _statusMessage = 'gRPC failed, falling back to WebSocket...';
        _isSearching = false;
      });
      // Fallback to WebSocket/HTTP
      if (_useWebSocket) {
        _searchWebSocket();
      } else {
        _searchHTTP();
      }
    }
  }

  Future<void> _processSearchStream(Stream<SearchResult> stream, String streamType) async {
    try {
      await for (final result in stream) {
        switch (result.type) {
          case SearchResultType.progress:
            if (result.progress != null) {
              setState(() {
                _progress = (result.progress!.percent / 2).toInt();  // Each stream is 50%
                _statusMessage = '$streamType: ${result.progress!.message}';
              });
            }
            break;

          case SearchResultType.partialResult:
            if (result.partialResult != null) {
              final adapter = result.partialResult!.adapterName;
              final partialSources = result.partialResult!.sources;

              // Convert partial sources to map format
              final newPartialResults = partialSources.map((source) {
                return {
                  'rank': 0,
                  'source': {
                    'id': source.id,
                    'title': source.title,
                    'url': source.url,
                    'source_type': source.sourceType,
                    'format': source.format,
                    'quality_score': source.qualityScore,
                    'indexer': source.indexer,
                    'magnet_link': source.magnetLink,
                    'size_bytes': source.sizeBytes,
                    'size_formatted': source.sizeFormatted,
                    'seeders': source.seeders,
                    'leechers': source.leechers,
                    'codec': source.codec,
                    'bitrate': source.bitrate,
                    'thumbnail_url': source.thumbnailUrl,
                    'duration_seconds': source.durationSeconds,
                  },
                  'explanation': '',
                  'tags': [],
                };
              }).toList();

              setState(() {
                // Add to appropriate list based on stream type
                if (streamType == 'streaming') {
                  _streamingResults.addAll(newPartialResults);
                } else {
                  _torrentResults.addAll(newPartialResults);
                }
                _results.addAll(newPartialResults);
              });
            }
            break;

          case SearchResultType.complete:
            if (result.completeResult != null) {
              setState(() {
                if (streamType == 'streaming') {
                  _streamingLoading = false;
                } else {
                  _torrentLoading = false;
                }
              });
            }
            break;

          case SearchResultType.error:
            if (result.error != null) {
              print('[$streamType] Error: ${result.error!.message}');
              setState(() {
                if (streamType == 'streaming') {
                  _streamingLoading = false;
                } else {
                  _torrentLoading = false;
                }
              });
            }
            break;
        }
      }
    } catch (e) {
      print('[$streamType] Stream processing error: $e');
      setState(() {
        if (streamType == 'streaming') {
          _streamingLoading = false;
        } else {
          _torrentLoading = false;
        }
      });
    }
  }

  Map<String, dynamic> _convertGrpcSourceToMap(RankedMusicSource ranked) {
    final source = ranked.source;
    return {
      'rank': ranked.rank,
      'source': {
        'id': source.id,
        'title': source.title,
        'url': source.url,
        'source_type': source.sourceType,
        'format': source.format,
        'quality_score': source.qualityScore,
        'indexer': source.indexer,
        'magnet_link': source.magnetLink,
        'size_bytes': source.sizeBytes,
        'size_formatted': source.sizeFormatted,
        'seeders': source.seeders,
        'leechers': source.leechers,
        'codec': source.codec,
        'bitrate': source.bitrate,
        'thumbnail_url': source.thumbnailUrl,
        'duration_seconds': source.durationSeconds,
      },
      'explanation': ranked.explanation,
      'tags': ranked.tags,
    };
  }

  void _searchWebSocket() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _streamingLoading = true;
      _torrentLoading = true;
      _progress = 0;
      _statusMessage = 'Connecting...';

      // Only clear results for new search (offset = 0), not when loading more
      if (_currentOffset == 0) {
        _results = [];
        _streamingResults = [];
        _torrentResults = [];
        _hasMoreResults = true;
        _totalFound = 0;
      }
    });

    try {
      // Connect to WebSocket (using _clientApiUrl to fix 0.0.0.0)
      final wsUrl = _clientApiUrl.replaceFirst('http', 'ws');
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/search'));

      // Get authentication data
      final authData = await _apiAuthService.getWebSocketAuth();

      // Send search request with authentication
      _channel!.sink.add(json.encode({
        'auth': authData,
        'query': _searchController.text,
        'format_filter': null,
        'min_seeders': 1,
        'limit': 20,
        'offset': _currentOffset,
      }));

      // Listen for messages
      _channel!.stream.listen(
        (message) {
          final data = json.decode(message);
          print('[WS] Received message type: ${data['type']}');

          switch (data['type']) {
            case 'progress':
              setState(() {
                _progress = data['percent'] ?? 0;
                _statusMessage = data['message'] ?? 'Searching...';
              });
              break;

            case 'partial_result':
              // Show progress as each adapter completes
              final adapter = data['adapter'] as String;
              final count = data['count'] ?? 0;
              print('[WS] Partial result from $adapter: $count results');
              setState(() {
                _statusMessage = 'Searching... ($adapter found $count results)';
              });
              break;

            case 'result':
              // This is the unified, quality-sorted results from the backend
              print('[WS] Result message received');
              final resultData = data['data'];
              print('[WS] resultData keys: ${resultData?.keys}');
              final newResults = List<Map<String, dynamic>>.from(
                resultData['results'] ?? []
              );
              print('[WS] Received ${newResults.length} results');

              setState(() {
                // For pagination, append new results to existing ones
                if (_currentOffset > 0) {
                  _results.addAll(newResults);
                } else {
                  // New search, replace results
                  _results = newResults;
                }
                print('[WS] Total _results: ${_results.length}');

                // Separate into streaming/torrent for display counts
                print('[WS] Starting filtering...');
                _streamingResults = _results.where((result) {
                  final source = result['source'] ?? result['torrent'];
                  final sourceType = source['source_type'] ?? 'torrent';
                  print('[FILTER] source_type: $sourceType, title: ${source['title']}');
                  return sourceType == 'youtube' || sourceType == 'piped' || sourceType == 'invidious';
                }).toList();
                print('[WS] Filtered _streamingResults: ${_streamingResults.length}');

                _torrentResults = _results.where((result) {
                  final source = result['source'] ?? result['torrent'];
                  final sourceType = source['source_type'] ?? 'torrent';
                  return sourceType == 'torrent';
                }).toList();
                print('[WS] Filtered _torrentResults: ${_torrentResults.length}');

                _streamingLoading = false;
                _torrentLoading = false;
                _applyFilter();
              });
              break;

            case 'complete':
              setState(() {
                _isSearching = false;
                _isLoadingMore = false;
                _streamingLoading = false;
                _torrentLoading = false;
                _progress = 100;
                _totalFound = data['total_found'] ?? 0;
                _hasMoreResults = _results.length < _totalFound;
                _statusMessage = 'Found ${_results.length} results (${_streamingResults.length} streaming, ${_torrentResults.length} torrents)';
              });
              _channel?.sink.close();
              _channel = null;
              break;

            case 'error':
              setState(() {
                _statusMessage = 'Error: ${data["message"]}';
                _isSearching = false;
                _streamingLoading = false;
                _torrentLoading = false;
              });
              _channel?.sink.close();
              _channel = null;
              break;
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _statusMessage = 'Connection error: $error';
            _isSearching = false;
            _streamingLoading = false;
            _torrentLoading = false;
          });
        },
        onDone: () {
          print('WebSocket closed');
          if (_isSearching) {
            setState(() {
              _statusMessage = 'Search completed';
              _isSearching = false;
              _streamingLoading = false;
              _torrentLoading = false;
            });
          }
        },
      );
    } catch (e, stackTrace) {
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'websocket_search',
        extras: {
          'query': _searchController.text,
          'api_url': appSettings.searchApiUrl,
        },
      );

      setState(() {
        _statusMessage = 'Connection error: $e';
        _isSearching = false;
        _streamingLoading = false;
        _torrentLoading = false;
      });
    }
  }

  void _searchHTTP() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _progress = 0;
      _statusMessage = 'Searching...';
      _results = [];
      _streamingResults = [];
      _torrentResults = [];
    });

    try {
      // Fire both requests concurrently
      final results = await Future.wait([
        _searchStreaming(),  // Usually faster (1-2s)
        _searchTorrents(),   // Usually slower (5-10s or timeout)
      ]);

      final streamingResults = results[0];
      final torrentResults = results[1];

      setState(() {
        _streamingResults = streamingResults;
        _torrentResults = torrentResults;
        // Combine results (streaming first for better UX)
        _results = [...streamingResults, ...torrentResults];
        _applyFilter();
        _statusMessage = 'Found ${_filteredResults.length} results (${streamingResults.length} streaming, ${torrentResults.length} torrents)';
        _isSearching = false;
      });
    } catch (e, stackTrace) {
      // Report to Glitchtip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'concurrent_search',
        extras: {
          'query': _searchController.text,
          'api_url': appSettings.searchApiUrl,
        },
      );

      setState(() {
        _statusMessage = 'Search error: $e';
        _isSearching = false;
      });
    }
  }

  void _search() {
    // Reset pagination for new search
    setState(() {
      _currentOffset = 0;
      _hasMoreResults = true;
      _totalFound = 0;
      _results = [];
      _streamingResults = [];
      _torrentResults = [];
      _filteredResults = [];
    });

    print('[SEARCH] Starting new search, offset reset to: $_currentOffset');

    // Try gRPC first (binary protocol, faster), fallback to WebSocket/HTTP
    print('[SEARCH] useGrpc: $_useGrpc');
    if (_useGrpc) {
      print('[SEARCH] → Using gRPC');
      _searchGrpc();
    } else if (_useWebSocket) {
      print('[SEARCH] → Using WebSocket');
      _searchWebSocket();
    } else {
      print('[SEARCH] → Using HTTP');
      _searchHTTP();
    }
  }

  void _showTransmissionHelp() {
    // Detect platform and build appropriate instructions
    String platformTitle;
    List<Widget> platformInstructions;

    if (Platform.isLinux) {
      platformTitle = 'Quick Setup (Linux):';
      platformInstructions = [
        const Text('1. Install Transmission:'),
        const SizedBox(height: 4),
        const SelectableText(
          '   sudo apt install transmission-daemon',
          style: TextStyle(fontFamily: 'Courier', backgroundColor: Color(0xFFF5F5F5)),
        ),
        const SizedBox(height: 4),
        const Text('   Or for Fedora:', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        const SelectableText(
          '   sudo dnf install transmission-daemon',
          style: TextStyle(fontFamily: 'Courier', backgroundColor: Color(0xFFF5F5F5)),
        ),
        const SizedBox(height: 12),
        const Text('2. Start Transmission daemon:'),
        const SizedBox(height: 4),
        const SelectableText(
          '   sudo systemctl start transmission-daemon',
          style: TextStyle(fontFamily: 'Courier', backgroundColor: Color(0xFFF5F5F5)),
        ),
      ];
    } else if (Platform.isWindows) {
      platformTitle = 'Quick Setup (Windows):';
      platformInstructions = [
        const Text('1. Download Transmission from:'),
        const SizedBox(height: 4),
        const SelectableText(
          '   https://transmissionbt.com/download',
          style: TextStyle(fontSize: 13, color: Colors.blue),
        ),
        const SizedBox(height: 12),
        const Text('2. Install and run Transmission'),
        const SizedBox(height: 4),
        const Text('   Keep it running in the background', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        const Text('3. (Optional) Auto-start with Windows:'),
        const SizedBox(height: 4),
        const Text('   Right-click system tray icon → "Start when Windows starts"', style: TextStyle(fontSize: 12)),
      ];
    } else {
      // macOS
      platformTitle = 'Quick Setup (macOS):';
      platformInstructions = [
        const Text('1. Install Transmission:'),
        const SizedBox(height: 4),
        const SelectableText(
          '   brew install transmission',
          style: TextStyle(fontFamily: 'Courier', backgroundColor: Color(0xFFF5F5F5)),
        ),
        const SizedBox(height: 12),
        const Text('2. Start Transmission daemon:'),
        const SizedBox(height: 4),
        const SelectableText(
          '   transmission-daemon',
          style: TextStyle(fontFamily: 'Courier', backgroundColor: Color(0xFFF5F5F5)),
        ),
        const SizedBox(height: 12),
        const Text('Or download the GUI app from:', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        const SelectableText(
          '   https://transmissionbt.com/download',
          style: TextStyle(fontSize: 13, color: Colors.blue),
        ),
      ];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Transmission Not Running'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TrustTune needs Transmission to download torrents.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Text(
                platformTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...platformInstructions,
              const SizedBox(height: 16),
              const Text(
                'See full setup guide at: github.com/trust-tune-net/karma-player',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  void _playStream(Map<String, dynamic> source) async {
    final url = source['url'];
    final title = source['title'];
    final codec = source['codec'];
    final bitrate = source['bitrate'];
    final sourceId = source['id'];

    if (url == null || url.toString().trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No streaming URL available'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Check if this is a YouTube Music URL that needs downloading
      if (url.toString().contains('music.youtube.com') && sourceId != null) {
        print('[YouTube Download] Detected YouTube Music URL');
        print('[YouTube Download]    Video ID: $sourceId');
        print('[YouTube Download]    Title: $title');

        if (!mounted) return;

        // Check if already downloading this video
        if (_youtubeDownloadService.isDownloading(sourceId)) {
          print('[YouTube Download] Already downloading $sourceId, skipping...');
          return; // Don't show dialog again if already downloading
        }

        // Track progress and status for toast updates
        double downloadProgress = 0.0;
        String? downloadStatus;
        OverlayEntry? toastOverlay;
        void Function(VoidCallback)? setToastState;
        bool isCanceled = false;

        // Create overlay entry for non-blocking toast
        void createToast() {
          final overlay = Overlay.of(context);
          if (overlay == null) return;

          toastOverlay = OverlayEntry(
            builder: (context) => Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: StatefulBuilder(
                builder: (context, setState) {
                  // Capture setState so progress callback can call it
                  setToastState = setState;

                  return YouTubeDownloadProgressToast(
                    title: title,
                    artist: source['artist'],
                    progress: downloadProgress,
                    status: downloadStatus,
                    onCancel: () async {
                      // Cancel the download
                      isCanceled = true;
                      await _youtubeDownloadService.cancelDownload(sourceId);
                      
                      // Dismiss toast
                      toastOverlay?.remove();
                      toastOverlay = null;
                      
                      // Show cancel message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Download canceled'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onDismiss: () {
                      toastOverlay?.remove();
                      toastOverlay = null;
                    },
                  );
                },
              ),
            ),
          );

          overlay.insert(toastOverlay!);
        }

        // Show non-blocking toast
        createToast();

        try {
          // Update progress callback that triggers toast rebuild
          void updateProgress(double progress) {
            if (isCanceled) return; // Don't update if canceled
            downloadProgress = progress;
            if (mounted && setToastState != null) {
              setToastState?.call(() {});
            }
          }

          // Update status callback that triggers toast rebuild
          void updateStatus(String status) {
            if (isCanceled) return; // Don't update if canceled
            downloadStatus = status;
            if (mounted && setToastState != null) {
              setToastState?.call(() {});
            }
          }

          // Download audio using yt-dlp with callback to refresh library
          // Pass title (and artist if available) to avoid metadata extraction
          final filePath = await _youtubeDownloadService.downloadAudio(
            sourceId,
            title: title,
            artist: source['artist'], // Pass artist if available in source
            onProgress: updateProgress,
            onStatus: updateStatus,
            onDownloadComplete: widget.onLibraryRefresh,
          );

          // Check if canceled before proceeding
          if (isCanceled) {
            return;
          }

          // Dismiss toast on completion
          if (mounted && toastOverlay != null) {
            toastOverlay!.remove();
            toastOverlay = null;
          }

          if (filePath == null || filePath.isEmpty) {
            throw Exception('Failed to download YouTube audio');
          }

          print('[YouTube Download] ✅ Ready for playback');
          print('[YouTube Download]    File: $filePath');

          // Look for folder.jpg in the same directory as the M4A file
          final fileDir = path.dirname(filePath);
          final folderJpgPath = path.join(fileDir, 'folder.jpg');
          final artworkPath = await File(folderJpgPath).exists() ? folderJpgPath : null;

          // Extract metadata from the actual downloaded M4A file
          final downloadedSong = await Song.fromFileWithMetadata(
            filePath,
            artworkPath: artworkPath, // Pass folder.jpg path
            useRealMetadata: true, // Read actual M4A metadata
          );

          // Play using shared playback service
          try {
            widget.onSongTap?.call(downloadedSong);
          } catch (e, stackTrace) {
            print('[YouTube Download] Error calling onSongTap: $e');
            AnalyticsService().captureError(
              e,
              stackTrace,
              context: 'youtube_play_callback',
              extras: {
                'video_id': sourceId,
                'title': title,
              },
            );
            // Rethrow to be caught by outer handler
            rethrow;
          }
        } catch (e) {
          // Dismiss toast if still open on error (unless it was canceled)
          if (!isCanceled && mounted && toastOverlay != null) {
            toastOverlay!.remove();
            toastOverlay = null;
          }
          
          // Only rethrow if not canceled (cancellation is expected)
          if (!isCanceled) {
            rethrow;
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now playing: $title'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        print('[YouTube Download] ▶️  Playing: $title');
      } else {
        // Non-YouTube streaming (shouldn't happen, but handle gracefully)
        print('[STREAMING] Non-YouTube URL: $url');
        throw Exception('Only YouTube Music streaming is supported');
      }
    } catch (e, stackTrace) {
      print('[YouTube Download] ❌ Error: $e');
      
      // Report to Glitchtip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'youtube_stream_play',
        extras: {
          'video_id': sourceId,
          'title': title,
          'url': url.toString(),
        },
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _startDownload(Map<String, dynamic> torrent) async {
    final magnetLink = torrent['magnet_link'] ?? torrent['url'];
    final title = torrent['title'];

    // Validate magnet link exists and is properly formatted
    if (magnetLink == null || magnetLink.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No magnet link available for this torrent'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate it starts with magnet:
    if (!magnetLink.toString().startsWith('magnet:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid magnet link format: ${magnetLink.toString().substring(0, 20)}...'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      print('Invalid magnet link: $magnetLink');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting download: $title')),
    );

    try {
      final transmissionClient = TransmissionClient(baseUrl: appSettings.transmissionRpcUrl);

      // Add torrent to transmission
      final torrentId = await transmissionClient.addTorrent(magnetLink: magnetLink);

      // Check torrent status
      final torrent = await transmissionClient.getTorrent(torrentId);
      final percentDone = torrent?.percentDone ?? 0.0;

      String message;
      Color backgroundColor;

      if (percentDone >= 1.0) {
        message = 'Already downloaded: $title';
        backgroundColor = Colors.blue;
      } else if (percentDone > 0) {
        message = 'Download in progress (${(percentDone * 100).toStringAsFixed(0)}%): $title';
        backgroundColor = Colors.orange;
      } else {
        message = 'Download started: $title';
        backgroundColor = Colors.green;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
      print('Torrent ID: $torrentId - ${(percentDone * 100).toStringAsFixed(1)}% complete');
    } catch (e) {
      // Check if it's a connection error (Transmission not running)
      final errorStr = e.toString();
      final isConnectionError = errorStr.contains('Connection refused') ||
                                 errorStr.contains('Failed to connect') ||
                                 errorStr.contains('SocketException');

      // Report to Glitchtip (non-connection errors only, to avoid spam)
      if (!isConnectionError) {
        AnalyticsService().captureError(
          e,
          StackTrace.current,
          context: 'torrent_download',
          extras: {
            'title': title,
            'magnet_link': magnetLink.toString().substring(0, 100),
          },
        );
      }

      if (isConnectionError) {
        // Transmission daemon is not running
        _showTransmissionHelp();
      } else {
        // Other error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting download: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('Download error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Row(
          children: [
            Text(
              'Discover Music',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            StatsBadges(
              onConnectionTap: _openDiagnostics,
            ), // No albums count for Search screen
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search for music',
                hintText: 'e.g., radiohead ok computer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              enabled: !_isSearching,
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),

            // Search Button
            FilledButton.icon(
              onPressed: _isSearching ? null : _search,
              icon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('Search'),
            ),
            const SizedBox(height: 12),

            // Quality and Source Controls (Collapsible)
            ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              title: const Text(
                'Quality & Source Filters',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: [
                // Re-order by quality toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Re-order by Quality',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Sort by quality score when search completes',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    Switch(
                      value: _reorderByQuality,
                      onChanged: (value) {
                        setState(() {
                          _reorderByQuality = value;
                          if (!_isSearching) {
                            _applyFilter();
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Source type toggles with Switch widgets
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Torrents',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _showTorrents,
                          onChanged: (value) {
                            setState(() {
                              _showTorrents = value;
                              _applyFilter();
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text(
                          'YouTube',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _showYouTube,
                          onChanged: (value) {
                            setState(() {
                              _showYouTube = value;
                              _applyFilter();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status and Progress
            if (_isSearching) ...[
              LinearProgressIndicator(value: _progress / 100),
              const SizedBox(height: 8),
            ],
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Source Filter Chips (above results)
            if (_results.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _sourceFilter == SourceFilter.all,
                    onSelected: (_) {
                      setState(() {
                        _sourceFilter = SourceFilter.all;
                        _applyFilter();
                        _saveFilterPreference(_sourceFilter);
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Torrents'),
                    selected: _sourceFilter == SourceFilter.torrents,
                    onSelected: (_) {
                      setState(() {
                        _sourceFilter = SourceFilter.torrents;
                        _applyFilter();
                        _saveFilterPreference(_sourceFilter);
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Streaming'),
                    selected: _sourceFilter == SourceFilter.streaming,
                    onSelected: (_) {
                      setState(() {
                        _sourceFilter = SourceFilter.streaming;
                        _applyFilter();
                        _saveFilterPreference(_sourceFilter);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Results Count
            if (_filteredResults.isNotEmpty) ...[
              Text(
                'Showing ${_filteredResults.length} results:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: ListView(
                controller: _scrollController,
                children: [
                  // Show filtered results (unified, sorted by quality)
                  if (_filteredResults.isNotEmpty) ...[
                    ..._filteredResults.map((result) => _buildResultCard(result)),
                  ],

                  // Loading more indicator
                  if (_isLoadingMore) ...[
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Loading more results...'),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // No results
                  if (_filteredResults.isEmpty && !_isSearching && !_streamingLoading && !_torrentLoading) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No results found',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBadge(Map<String, dynamic> source) {
    final format = source['format']?.toString().toUpperCase() ?? '';
    final bitrate = source['bitrate']?.toString() ?? '';
    final codec = source['codec']?.toString().toUpperCase() ?? '';
    final sourceType = source['source_type'] ?? 'torrent';
    final isStreaming = sourceType == 'youtube' || sourceType == 'piped';

    // DEBUG: Log received values to verify gRPC transmission
    final title = source['title']?.toString() ?? '';
    print('🐛 BADGE DEBUG: format="$format", bitrate="$bitrate", codec="$codec" | ${title.substring(0, title.length > 50 ? 50 : title.length)}');

    String label = '';
    Color badgeColor = Colors.grey;

    if (format == 'FLAC') {
      // High-res FLAC: Use bitrate field populated by server (format: "24-96", "24-192", etc.)
      if (bitrate.isNotEmpty) {
        // Parse bitrate format: "24-192", "24-96", "24-44", "16-44", etc.
        final parts = bitrate.split('-');
        if (parts.length == 2) {
          final bitDepth = int.tryParse(parts[0]) ?? 16;
          final sampleRate = int.tryParse(parts[1]) ?? 44;
          label = 'FLAC $bitDepth/$sampleRate';

          // Calculate quality score: (bit_depth * sample_rate)
          // Higher score = better quality, assign color dynamically
          final qualityScore = bitDepth * sampleRate;

          if (qualityScore >= 2400) {  // e.g., 24-bit × 192kHz = 4608
            badgeColor = Colors.deepPurple; // Highest quality
          } else if (qualityScore >= 1800) {  // e.g., 24-bit × 96kHz = 2304
            badgeColor = Colors.deepPurple.shade400; // High quality
          } else if (qualityScore >= 1000) {  // e.g., 24-bit × 44kHz = 1056
            badgeColor = Colors.purple; // 24-bit standard
          } else {  // e.g., 16-bit × 44kHz = 704 (CD quality)
            badgeColor = Colors.purple.shade300;
          }
        } else {
          // Fallback if format doesn't match expected pattern
          label = 'FLAC $bitrate';
          badgeColor = Colors.purple;
        }
      } else {
        label = 'FLAC';
        badgeColor = Colors.purple.shade300;
      }
    } else if (format == 'MP3') {
      // MP3: Quality by bitrate
      if (bitrate.contains('320')) {
        label = 'MP3 320';
        badgeColor = Colors.green.shade700;
      } else if (bitrate.contains('256')) {
        label = 'MP3 256';
        badgeColor = Colors.green.shade600;
      } else if (bitrate.isNotEmpty) {
        label = 'MP3 $bitrate';
        badgeColor = Colors.amber.shade700;
      } else {
        label = 'MP3';
        badgeColor = Colors.amber.shade600;
      }
    } else if (format == 'M4A' || format == 'AAC') {
      label = bitrate.isNotEmpty ? 'M4A $bitrate' : 'M4A';
      badgeColor = Colors.orange.shade600;
    } else if (isStreaming) {
      // Streaming: Show codec + bitrate
      if (codec.isNotEmpty && bitrate.isNotEmpty) {
        label = '$codec $bitrate';
      } else if (codec.isNotEmpty) {
        label = codec;
      } else {
        label = 'YouTube';
      }
      badgeColor = Colors.blue.shade600;
    } else if (format.isNotEmpty) {
      // Other formats: Just show format
      label = format;
      badgeColor = Colors.blueGrey.shade600;
    } else {
      // Fallback
      label = 'Unknown';
      badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final source = result['source'] ?? result['torrent'];
    final sourceType = source['source_type'] ?? 'torrent';
    final isStreaming = sourceType == 'youtube' || sourceType == 'piped';

    return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: _buildQualityBadge(source),
                      title: Text(
                        source['title'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(result['explanation']),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              // Source type badge
                              Chip(
                                avatar: Icon(
                                  isStreaming ? Icons.stream : Icons.storage,
                                  size: 16,
                                ),
                                label: Text(isStreaming ? 'Streaming' : 'Torrent'),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                backgroundColor: isStreaming
                                    ? Colors.blue.withOpacity(0.2)
                                    : Colors.green.withOpacity(0.2),
                              ),
                              if (source['format'] != null)
                                Chip(
                                  label: Text(source['format']),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              // Show seeders for torrents, codec for streaming
                              if (!isStreaming && source['seeders'] != null)
                                Chip(
                                  label: Text('${source['seeders']} seeders'),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              if (isStreaming && source['codec'] != null)
                                Chip(
                                  label: Text(source['codec']),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              // Show bitrate for both
                              if (source['bitrate'] != null)
                                Chip(
                                  label: Text(source['bitrate']),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              // Show size for torrents only
                              if (!isStreaming && source['size_formatted'] != null)
                                Chip(
                                  label: Text(source['size_formatted']),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              // Download/Play button (more visible now!)
                              ActionChip(
                                avatar: Icon(
                                  isStreaming ? Icons.play_arrow : Icons.download,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  isStreaming ? 'Play' : 'Download',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                backgroundColor: const Color(0xFFA855F7),
                                onPressed: isStreaming
                                    ? () => _playStream(source)
                                    : () => _startDownload(source),
                              ),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
  }
}

