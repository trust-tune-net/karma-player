import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
import '../widgets/youtube_download_progress_dialog.dart';
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
    _initializeGrpcService();
    _loadFilterPreference();
    _verifyYtDlp();
    _scrollController.addListener(_onScroll);
  }

  void _initializeGrpcService() {
    try {
      // Parse gRPC host from API URL (using _clientApiUrl to fix 0.0.0.0)
      final uri = Uri.parse(_clientApiUrl);

      print('[gRPC] Initializing: ${uri.host}:50051 (secure: ${uri.scheme == 'https'})');
      _grpcService = SearchServiceGrpc(
        authService: _apiAuthService,
        deviceService: _deviceService,
        host: uri.host,
        port: 50051,  // gRPC port
        useSecure: uri.scheme == 'https',
      );
      print('[gRPC] ✅ Service initialized successfully');
    } catch (e) {
      print('[gRPC] ❌ Initialization failed: $e');
      // Will fall back to WebSocket/HTTP
    }
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

    // Perform another search with new offset
    _searchWebSocket();
  }

  /// Verify yt-dlp binary is available and working
  void _verifyYtDlp() async {
    // Run verification in background, don't block UI
    await _youtubeDownloadService.verifyYtDlp();
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
      switch (_sourceFilter) {
        case SourceFilter.all:
          _filteredResults = _results;
          break;
        case SourceFilter.torrents:
          _filteredResults = _results.where((result) {
            final source = result['source'] ?? result['torrent'];
            final sourceType = source['source_type'] ?? 'torrent';
            return sourceType == 'torrent';
          }).toList();
          break;
        case SourceFilter.streaming:
          _filteredResults = _results.where((result) {
            final source = result['source'] ?? result['torrent'];
            final sourceType = source['source_type'] ?? 'torrent';
            return sourceType == 'youtube' || sourceType == 'piped';
          }).toList();
          break;
      }
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
      if (_grpcService == null) {
        throw Exception('gRPC service not initialized');
      }

      // Execute gRPC search with streaming
      final stream = _grpcService!.search(
        query: _searchController.text,
        minSeeders: 1,
        limit: 20,
        offset: _currentOffset,
      );

      await for (final result in stream) {
        switch (result.type) {
          case SearchResultType.progress:
            if (result.progress != null) {
              setState(() {
                _progress = result.progress!.percent;
                _statusMessage = result.progress!.message;
              });
            }
            break;

          case SearchResultType.partialResult:
            if (result.partialResult != null) {
              final adapter = result.partialResult!.adapterName;
              final count = result.partialResult!.sources.length;
              setState(() {
                _statusMessage = 'Searching... ($adapter found $count results)';
              });
            }
            break;

          case SearchResultType.complete:
            if (result.completeResult != null) {
              final newResults = result.completeResult!.rankedSources
                  .map((ranked) => _convertGrpcSourceToMap(ranked))
                  .toList();

              setState(() {
                if (_currentOffset > 0) {
                  _results.addAll(newResults);
                } else {
                  _results = newResults;
                }

                // Separate streaming/torrent
                _streamingResults = _results.where((r) {
                  final source = r['source'] ?? r['torrent'];
                  final sourceType = source['source_type'] ?? 'torrent';
                  return ['youtube', 'piped', 'invidious'].contains(sourceType);
                }).toList();

                _torrentResults = _results.where((r) {
                  final source = r['source'] ?? r['torrent'];
                  final sourceType = source['source_type'] ?? 'torrent';
                  return sourceType == 'torrent';
                }).toList();

                _applyFilter();
                _streamingLoading = false;
                _torrentLoading = false;
                _isSearching = false;
                _progress = 100;
                _statusMessage = 'Found ${_results.length} results (${_streamingResults.length} streaming, ${_torrentResults.length} torrents)';

                // Update pagination state
                _totalFound = result.completeResult!.totalFound;
                _hasMoreResults = (_currentOffset + _results.length) < _totalFound;
              });
            }
            break;

          case SearchResultType.error:
            if (result.error != null) {
              throw Exception(result.error!.message);
            }
            break;
        }
      }
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
              setState(() {
                _statusMessage = 'Searching... ($adapter found $count results)';
              });
              break;

            case 'result':
              // This is the unified, quality-sorted results from the backend
              final resultData = data['data'];
              final newResults = List<Map<String, dynamic>>.from(
                resultData['results'] ?? []
              );

              setState(() {
                // For pagination, append new results to existing ones
                if (_currentOffset > 0) {
                  _results.addAll(newResults);
                } else {
                  // New search, replace results
                  _results = newResults;
                }

                // Separate into streaming/torrent for display counts
                _streamingResults = _results.where((result) {
                  final source = result['source'] ?? result['torrent'];
                  final sourceType = source['source_type'] ?? 'torrent';
                  return sourceType == 'youtube' || sourceType == 'piped';
                }).toList();

                _torrentResults = _results.where((result) {
                  final source = result['source'] ?? result['torrent'];
                  final sourceType = source['source_type'] ?? 'torrent';
                  return sourceType == 'torrent';
                }).toList();

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
    });

    // Try gRPC first (binary protocol, faster), fallback to WebSocket/HTTP
    print('[SEARCH] useGrpc: $_useGrpc, grpcService: ${_grpcService != null ? 'available' : 'null'}');
    if (_useGrpc && _grpcService != null) {
      print('[SEARCH] → Using gRPC');
      _searchGrpc();
    } else if (_useWebSocket) {
      print('[SEARCH] → Using WebSocket (gRPC unavailable)');
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
            const StatsBadges(), // No albums count for Search screen
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
            const SizedBox(height: 16),

            // Source Filter Toggle
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
              const SizedBox(height: 8),
            ],

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

            // Results List
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

  Widget _buildResultCard(Map<String, dynamic> result) {
    final source = result['source'] ?? result['torrent'];
    final sourceType = source['source_type'] ?? 'torrent';
    final isStreaming = sourceType == 'youtube' || sourceType == 'piped';

    return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: result['rank'] == 1
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Text(
                          '${result['rank']}',
                          style: TextStyle(
                            color: result['rank'] == 1
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: result['rank'] == 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
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
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(isStreaming ? Icons.play_arrow : Icons.download),
                        onPressed: isStreaming
                            ? () => _playStream(source)
                            : () => _startDownload(source),
                        tooltip: isStreaming ? 'Play Stream' : 'Download',
                      ),
                      isThreeLine: true,
                    ),
                  );
  }
}

