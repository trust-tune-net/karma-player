import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/torrent.dart' as torrent_model;
import '../models/song.dart';
import '../services/transmission_client.dart';
import '../services/playback_service.dart';
import '../main.dart';

enum SourceFilter { all, torrents, streaming }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  // Create PlaybackService instance
  final PlaybackService _playbackService = PlaybackService();
  final TextEditingController _searchController = TextEditingController();
  WebSocketChannel? _channel;

  String _statusMessage = 'Enter a search query';
  int _progress = 0;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _filteredResults = [];
  bool _isSearching = false;
  SourceFilter _sourceFilter = SourceFilter.all;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFilterPreference();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.sink.close();
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

  void _search() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _progress = 0;
      _statusMessage = 'Searching...';
      _results = [];
    });

    try {
      // Make HTTP POST request to search API
      final response = await http.post(
        Uri.parse('${appSettings.searchApiUrl}/api/search'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': _searchController.text,
          'format_filter': null,
          'min_seeders': 1,
          'limit': 50,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _results = List<Map<String, dynamic>>.from(data['results'] ?? []);
          _applyFilter();
          _statusMessage = 'Found ${_filteredResults.length} of ${_results.length} results';
          _isSearching = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Search failed: ${response.statusCode}';
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Search error: $e';
        _isSearching = false;
      });
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
      // Create a Song object for streaming
      final streamingSong = Song(
        id: url.hashCode.toString(),
        title: title,
        artist: 'YouTube Music',
        filePath: url, // media_kit supports HTTP URLs
        format: codec?.toUpperCase() ?? 'OPUS',
        bitrate: bitrate != null ? int.tryParse(bitrate.replaceAll(RegExp(r'[^\d]'), '')) : null,
      );

      // Play the streaming source
      _playbackService.playSong(streamingSong);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Now streaming: $title'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      print('[STREAMING] Playing: $title');
      print('[STREAMING] URL: ${url.length > 60 ? url.substring(0, 60) : url}${url.length > 60 ? '...' : ''}');
    } catch (e) {
      print('[STREAMING] Error playing stream: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing stream: ${e.toString()}'),
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
              child: ListView.builder(
                itemCount: _filteredResults.length,
                itemBuilder: (context, index) {
                  final result = _filteredResults[index];
                  // Support both old 'torrent' and new 'source' keys for backward compatibility
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

