import 'package:flutter/material.dart';

import '../../controllers/library_controller.dart';
import '../../models/song.dart';
import 'library_track_list_item.dart';

class LibraryFilesView extends StatefulWidget {
  const LibraryFilesView({
    super.key,
    required this.controller,
    required this.songs,
    required this.onSongTap,
    required this.onVerifySong,
    required this.onOpenFolder,
    required this.currentSong,
  });

  final LibraryController controller;
  final List<Song> songs;
  final Song? currentSong;
  final void Function(Song song) onSongTap;
  final void Function(Song song) onVerifySong;
  final void Function(String path) onOpenFolder;

  @override
  State<LibraryFilesView> createState() => _LibraryFilesViewState();
}

class _LibraryFilesViewState extends State<LibraryFilesView> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.hasFiles) {
      return _buildEmptyFilesState(context);
    }

    if (widget.songs.isEmpty) {
      return _buildNoResultsState(context);
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: widget.songs.length,
        itemBuilder: (context, index) {
          final song = widget.songs[index];
          final isPlaying = widget.currentSong?.id == song.id;
          final isExpanded = widget.controller.isSongExpanded(song.id);

          return LibraryTrackListItem(
            song: song,
            isPlaying: isPlaying,
            isExpanded: isExpanded,
            onTap: () => widget.onSongTap(song),
            onToggleExpanded: () => widget.controller.updateExpandedSongId(
              isExpanded ? null : song.id,
            ),
            onVerify: () => widget.onVerifySong(song),
            onOpenFolder: () => widget.onOpenFolder(song.filePath),
          );
        },
      ),
    );
  }

  Widget _buildEmptyFilesState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            widget.controller.isScanning
                ? 'Scanning for files...'
                : 'No audio files found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add music files to ~/Music',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No files match your filters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Adjust search or format filters',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
