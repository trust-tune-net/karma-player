import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/library_controller.dart';
import '../../models/album.dart';
import 'library_album_card.dart';

class LibraryAlbumGrid extends StatelessWidget {
  const LibraryAlbumGrid({
    super.key,
    required this.controller,
    required this.searchController,
    required this.onAlbumSelected,
  });

  final LibraryController controller;
  final TextEditingController searchController;
  final ValueChanged<Album> onAlbumSelected;

  @override
  Widget build(BuildContext context) {
    final albums = controller.albums;
    final displayAlbums = controller.displayAlbums;
    final isScanning = controller.isScanning;
    final statusMessage = controller.statusMessage;
    final availableFormats = controller.availableFormats.toList()..sort();

    return Column(
      children: [
        if (statusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (isScanning) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        if (albums.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildSearchField(context)),
                const SizedBox(width: 16),
                _buildSortMenu(context),
              ],
            ),
          ),
        if (controller.hasActiveFormatFilter || availableFormats.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (controller.hasActiveFormatFilter)
                    ActionChip(
                      label: const Text('Clear format filters'),
                      onPressed: controller.clearFormatFilters,
                      avatar: const Icon(Icons.clear, size: 16),
                    ),
                  ...availableFormats.map(
                    (format) => FilterChip(
                      selected: controller.selectedFormats.contains(format),
                      label:
                          Text('$format (${controller.formatCount(format)})'),
                      onSelected: (_) =>
                          controller.toggleFormatSelection(format),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildAlbumContent(context, albums, displayAlbums),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: TextField(
        controller: searchController,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: 'Search albums or artists...',
          hintStyle:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF888888)),
          prefixIcon:
              const Icon(Icons.search, size: 20, color: Color(0xFF888888)),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  color: const Color(0xFF888888),
                  onPressed: () {
                    searchController.clear();
                    controller.updateSearchQuery('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSortMenu(BuildContext context) {
    final sortCriteria = controller.sortCriteria;
    final sortAscending = controller.sortAscending;

    String label;
    switch (sortCriteria) {
      case SortCriteria.title:
        label = 'Title';
        break;
      case SortCriteria.artist:
        label = 'Artist';
        break;
      case SortCriteria.trackCount:
        label = 'Tracks';
        break;
      case SortCriteria.year:
        label = 'Year';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<SortCriteria>(
          tooltip: 'Change sort order',
          initialValue: sortCriteria,
          onSelected: controller.updateSortCriteria,
          itemBuilder: (context) => const [
            PopupMenuItem(value: SortCriteria.title, child: Text('Title')),
            PopupMenuItem(value: SortCriteria.artist, child: Text('Artist')),
            PopupMenuItem(
                value: SortCriteria.trackCount, child: Text('Track count')),
            PopupMenuItem(value: SortCriteria.year, child: Text('Year')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF333333), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 18),
                const SizedBox(width: 8),
                Text('Sort: $label', style: GoogleFonts.inter(fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: sortAscending ? 'Sort descending' : 'Sort ascending',
          icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18),
          onPressed: controller.toggleSortOrder,
        ),
      ],
    );
  }

  Widget _buildAlbumContent(
    BuildContext context,
    List<Album> albums,
    List<Album> displayAlbums,
  ) {
    if (albums.isEmpty) {
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
              controller.isScanning
                  ? 'Scanning for music...'
                  : 'No albums found',
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

    if (displayAlbums.isEmpty) {
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
}
