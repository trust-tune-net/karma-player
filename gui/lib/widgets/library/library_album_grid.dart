import 'package:flutter/material.dart';

import '../../controllers/library_controller.dart';
import '../../models/album.dart';
import 'library_album_card.dart';

class LibraryAlbumGrid extends StatelessWidget {
  const LibraryAlbumGrid({
    super.key,
    required this.controller,
    required this.onAlbumSelected,
  });

  final LibraryController controller;
  final ValueChanged<Album> onAlbumSelected;

  @override
  Widget build(BuildContext context) {
    final albums = controller.albums;
    final displayAlbums = controller.displayAlbums;

    if (albums.isEmpty) {
      return _buildEmptyLibraryState(context);
    }

    if (displayAlbums.isEmpty) {
      return _buildNoResultsState(context);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.75,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: displayAlbums.length,
      itemBuilder: (context, index) {
        final album = displayAlbums[index];
        final isDownloading =
            controller.downloadProgress.containsKey(album.name);
        final progress = controller.downloadProgress[album.name] ?? 0.0;
        final showProgress = isDownloading && progress < 1.0;
        final matchingSongCount = controller.matchingSongCount(album);
        final albumMatches = controller.albumMatchesSearch(album);

        return LibraryAlbumCard(
          album: album,
          showProgress: showProgress,
          progress: progress,
          matchingSongCount: matchingSongCount,
          showSongMatchBadge: controller.searchQuery.isNotEmpty &&
              !albumMatches &&
              matchingSongCount > 0,
          onTap: () => onAlbumSelected(album),
        );
      },
    );
  }

  Widget _buildEmptyLibraryState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            controller.isScanning ? 'Scanning for music...' : 'No albums found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add music to ~/Music',
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
            'No albums match your search',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
