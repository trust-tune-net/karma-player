import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/transmission_client.dart';
import '../main.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _downloads = [];
  bool _isLoading = true;
  Timer? _pollTimer;
  late final TransmissionClient _transmissionClient;

  // Format bytes per second to human-readable speed
  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    if (bytesPerSecond > 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSecond > 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '$bytesPerSecond B/s';
  }

  // Format ETA seconds to human-readable time
  String _formatETA(int seconds) {
    if (seconds < 0) return 'Unknown';
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }

  // Get human-friendly status text (abstract torrent complexity)
  String _getStatusText(String status) {
    switch (status) {
      case 'download':
      case 'download_wait':
        return 'Downloading';
      case 'seed':
      case 'seed_wait':
        return 'Complete'; // Abstract "seeding" - file is ready to play
      case 'check':
      case 'check_wait':
        return 'Checking';
      case 'stopped':
        return 'Paused';
      default:
        return status;
    }
  }

  @override
  void initState() {
    super.initState();
    _transmissionClient = TransmissionClient(baseUrl: appSettings.transmissionRpcUrl);

    // Delay first load to give daemon time to start (avoid race condition)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _loadDownloads();
        // Start polling after first successful attempt
        _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadDownloads());
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    try {
      print('[Downloads] Fetching torrents from transmission...');
      final torrents = await _transmissionClient.getTorrents();
      print('[Downloads] Got ${torrents.length} torrents from transmission');

      for (var t in torrents) {
        print('[Downloads]   - [${t.id}] ${t.name} (${(t.percentDone * 100).toStringAsFixed(1)}%) status=${t.status}');
      }

      if (mounted) {
        setState(() {
          // Filter: only show incomplete downloads (< 100%)
          final activeTorrents = torrents.where((t) {
            final isActive = t.percentDone < 1.0;
            print('[Downloads] Torrent ${t.id}: percentDone=${t.percentDone}, status=${t.status}, isActive=$isActive');
            return isActive;
          }).toList();

          // Convert torrents to the same format expected by UI
          _downloads = activeTorrents.map((t) => {
            'id': t.id.toString(),
            'title': t.name,
            'progress': t.percentDone,  // Already 0.0-1.0
            'status': t.status,
            'download_speed': t.rateDownload,
            'upload_speed': t.rateUpload,
            'eta': t.eta,
          }).toList();
          _isLoading = false;
          print('[Downloads] Updated UI with ${_downloads.length} active downloads (${torrents.length} total)');
        });
      } else {
        print('[Downloads] Widget not mounted, skipping setState');
      }
    } catch (e) {
      print('[Downloads] Error loading downloads: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteDownload(String downloadId, String title) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "$title"?\n\nThis will remove the download but keep any completed files.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Delete via transmission
    try {
      final torrentId = int.parse(downloadId);
      await _transmissionClient.removeTorrents(ids: [torrentId], deleteData: false);

      // Refresh the list
      _loadDownloads();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "$title"')),
        );
      }
    } catch (e) {
      print('Error deleting download: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting download')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Row(
          children: [
            Text(
              'Downloads',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const StatsBadges(), // No albums count for Downloads screen
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No downloads yet',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start downloading music from the Search tab',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _downloads.length,
                  itemBuilder: (context, index) {
                    final download = _downloads[index];
                    final progress = (download['progress'] ?? 0.0) as double;
                    final status = download['status'] ?? 'unknown';
                    final title = download['title'] ?? 'Unknown';
                    final downloadId = download['id'] ?? '';
                    final downloadSpeed = download['download_speed'] as int? ?? 0;
                    final uploadSpeed = download['upload_speed'] as int? ?? 0;
                    final eta = download['eta'] as int? ?? -1;

                    // Build status line with speed and ETA (user-friendly, abstract torrent complexity)
                    String statusLine = '${(progress * 100).toStringAsFixed(1)}%';
                    if (status == 'download' && downloadSpeed > 0) {
                      statusLine += ' • ↓ ${_formatSpeed(downloadSpeed)}';
                      if (uploadSpeed > 0) {
                        statusLine += ' • ↑ ${_formatSpeed(uploadSpeed)}';
                      }
                      if (eta > 0) {
                        statusLine += ' • ${_formatETA(eta)}';
                      }
                    } else if (status == 'seed') {
                      // Don't show "seeding" - just show upload speed if actively uploading
                      if (uploadSpeed > 0) {
                        statusLine += ' • Sharing • ↑ ${_formatSpeed(uploadSpeed)}';
                      } else {
                        statusLine += ' • ${_getStatusText(status)}';
                      }
                    } else {
                      statusLine += ' • ${_getStatusText(status)}';
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: status == 'download'
                            ? Theme.of(context).colorScheme.primaryContainer
                            : status == 'seed'
                                ? const Color(0xFF10B981).withOpacity(0.2) // Green for complete
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          status == 'download'
                              ? Icons.downloading
                              : status == 'seed'
                                  ? Icons.check_circle // Complete checkmark instead of upload
                                  : status == 'check'
                                      ? Icons.check_circle_outline
                                      : Icons.pause_circle_outline,
                          color: status == 'download'
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : status == 'seed'
                                  ? const Color(0xFF10B981) // Green for complete
                                  : null,
                        ),
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusLine,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteDownload(downloadId, title),
                        tooltip: 'Remove',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
    );
  }
}
