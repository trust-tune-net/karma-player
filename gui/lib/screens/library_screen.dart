import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/library_controller.dart';
import '../main.dart';
import '../models/song.dart';
import '../services/audio_quality_verification_service.dart';
import '../services/analytics_service.dart';
import '../widgets/library/library_album_detail.dart';
import '../widgets/library/library_album_grid.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.onSongTap,
    this.currentSong,
  });

  final Function(Song song, {List<Song>? queue, bool? isShuffled}) onSongTap;
  final Song? currentSong;

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  late final LibraryController _controller;
  late final TextEditingController _searchController;
  late final TextEditingController _albumTrackFilterController;
  final AudioQualityVerificationService _audioVerificationService =
      AudioQualityVerificationService();

  @override
  void initState() {
    super.initState();
    _controller = LibraryController()
      ..addListener(_onControllerChanged)
      ..initialize();

    _searchController = TextEditingController()
      ..addListener(() {
        _controller.updateSearchQuery(_searchController.text.trim());
      });

    _albumTrackFilterController = TextEditingController()
      ..addListener(() {
        _controller.updateAlbumTrackFilter(
          _albumTrackFilterController.text.trim().toLowerCase(),
        );
      });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _searchController.dispose();
    _albumTrackFilterController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});

    if (_controller.hasConnectionLostNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Network connectivity issue - working offline'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2A2A2E),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _controller.markConnectionNotificationHandled();
      });
    }
  }

  void resetToAlbumsView() {
    _controller.clearSelectedAlbum();
    _albumTrackFilterController.clear();
  }

  void refreshLibrary() {
    _controller.refreshLibrary();
  }

  void _verifySongQuality(Song song) {
    final source = <String, dynamic>{
      'format': song.format,
      'bitrate': song.bitrate?.toString(),
    };

    _audioVerificationService.verifyAudioQuality(
      context,
      source,
      filePath: song.filePath,
    );
  }

  Future<void> _openFileLocation(String filePath) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', filePath]);
      } else if (Platform.isLinux) {
        final dir = filePath.substring(0, filePath.lastIndexOf('/'));
        try {
          await Process.run('nautilus', ['--select', filePath]);
        } catch (_) {
          await Process.run('xdg-open', [dir]);
        }
      }
    } catch (error, stackTrace) {
      AnalyticsService().captureError(
        error,
        stackTrace,
        context: 'open_file_location_library',
        extras: {
          'platform': Platform.operatingSystem,
          'path': filePath,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedAlbum = _controller.selectedAlbum;

    if (selectedAlbum != null) {
      return Scaffold(
        body: LibraryAlbumDetail(
          controller: _controller,
          album: selectedAlbum,
          trackFilterController: _albumTrackFilterController,
          onBack: resetToAlbumsView,
          onSongTap: widget.onSongTap,
          currentSong: widget.currentSong,
          onVerifySong: _verifySongQuality,
          onOpenFolder: _openFileLocation,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Row(
          children: [
            Text(
              'Library',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            StatsBadges(
              onConnectionTap: _controller.checkHealth,
            ),
          ],
        ),
      ),
      body: LibraryAlbumGrid(
        controller: _controller,
        searchController: _searchController,
        onAlbumSelected: (album) {
          _controller.selectAlbum(album);
          _albumTrackFilterController.clear();
        },
      ),
    );
  }
}
