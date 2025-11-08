import 'package:flutter/material.dart';

import '../../controllers/library_controller.dart';
import '../../models/song.dart';
import 'library_track_list_item.dart';

class LibraryFilesView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!controller.hasFiles) {
      return _buildEmptyFilesState(context);
    }

    if (songs.isEmpty) {
      return _buildNoResultsState(context);
    }

    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final isPlaying = currentSong?.id == song.id;
          final isExpanded = controller.isSongExpanded(song.id);

          return LibraryTrackListItem(
            song: song,
            isPlaying: isPlaying,
            isExpanded: isExpanded,
            onTap: () => onSongTap(song),
            onToggleExpanded: () => controller.updateExpandedSongId(
              isExpanded ? null : song.id,
            ),
            onVerify: () => onVerifySong(song),
            onOpenFolder: () => onOpenFolder(song.filePath),
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
            controller.isScanning
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
