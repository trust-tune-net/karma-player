import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/torrent.dart' as torrent_model;
import '../services/transmission_client.dart';
import '../main.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  WebSocketChannel? _channel;

  String _statusMessage = 'Enter a search query';
  int _progress = 0;
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.sink.close();
    super.dispose();
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
          _statusMessage = 'Found ${_results.length} results';
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

    if (url == null || url.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No streaming URL available'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // TODO: Implement streaming playback
    // For now, show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Streaming playback coming soon!\n$title'),
        duration: const Duration(seconds: 3),
      ),
    );
    print('Play stream: $url');
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
            const SizedBox(height: 24),

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
            if (_results.isNotEmpty) ...[
              Text(
                'Found ${_results.length} results:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
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

