import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/library_controller.dart';
import '../../main.dart';
import '../../models/album.dart';
import '../../models/song.dart';
import '../../utils/library_utils.dart';
import 'library_track_filter_header.dart';
import 'library_track_list_item.dart';

class LibraryAlbumDetail extends StatefulWidget {
  const LibraryAlbumDetail({
    super.key,
    required this.controller,
    required this.album,
    required this.trackFilterController,
    required this.onBack,
    required this.onSongTap,
    required this.currentSong,
    required this.onVerifySong,
    required this.onOpenFolder,
  });

  final LibraryController controller;
  final Album album;
  final TextEditingController trackFilterController;
  final VoidCallback onBack;
  final void Function(Song song, {List<Song>? queue, bool? isShuffled})
      onSongTap;
  final Song? currentSong;
  final void Function(Song song) onVerifySong;
  final void Function(String path) onOpenFolder;

  @override
  State<LibraryAlbumDetail> createState() => _LibraryAlbumDetailState();
}

class _LibraryAlbumDetailState extends State<LibraryAlbumDetail> {
  @override
  void initState() {
    super.initState();
    _scheduleMetadataLoad();
  }

  @override
  void didUpdateWidget(LibraryAlbumDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.album.id != oldWidget.album.id) {
      _scheduleMetadataLoad();
    }
  }

  void _scheduleMetadataLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.lazyLoadMetadata(widget.album);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final album = widget.album;
    final canOpenFolder =
        album.path.isNotEmpty && !album.path.startsWith('__virtual');
    final discGroups = controller.groupSongsByDisc(album.songs);
    final hasMultipleDiscs = discGroups.length > 1;
    final filter = controller.albumTrackFilter;
    final showFilter = album.songs.length >= 15;

    return CustomScrollView(
      slivers: [
        if (controller.isLoadingMetadata)
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading audio quality details...',
                    style:
                        GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        SliverAppBar(
          backgroundColor: const Color(0xFF000000),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: LayoutBuilder(
            builder: (context, constraints) {
              final expandRatio = (constraints.maxHeight - kToolbarHeight) /
                  (280 - kToolbarHeight);

              return FlexibleSpaceBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        album.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: expandRatio > 0.3
                              ? const [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 3.0,
                                    color: Color.fromARGB(128, 0, 0, 0),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (canOpenFolder)
                      IconButton(
                        icon: const Icon(Icons.folder_open, size: 18),
                        iconSize: 18,
                        color: Colors.white70,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Open album folder',
                        onPressed: () => widget.onOpenFolder(album.path),
                      ),
                  ],
                ),
                titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (album.artworkPath != null)
                      Image.file(
                        File(album.artworkPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Icon(Icons.album, size: 128),
                        ),
                      )
                    else
                      Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.album, size: 128),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.artist,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${album.trackCount} tracks',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: album.songs.isEmpty
                          ? null
                          : () => widget.onSongTap(
                                album.songs.first,
                                queue: album.songs,
                              ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: album.songs.isEmpty
                          ? null
                          : () {
                              final shuffled = List<Song>.from(album.songs)
                                ..shuffle();
                              widget.onSongTap(
                                shuffled.first,
                                queue: album.songs,
                                isShuffled: true,
                              );
                            },
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Shuffle'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        if (showFilter)
          SliverPersistentHeader(
            pinned: true,
            delegate: LibraryTrackFilterHeader(
              controller: widget.trackFilterController,
              filterText: filter,
              onClear: () => widget.trackFilterController.clear(),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'Tracks',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        if (hasMultipleDiscs)
          ..._buildDiscGroupedTrackList(album, discGroups, filter)
        else
          _buildTrackList(album, filter),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  SliverList _buildTrackList(Album album, String filter) {
    final songs = filter.isEmpty
        ? album.songs
        : album.songs
            .where((song) => LibraryUtils.matchesSongQuery(song, filter))
            .toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= songs.length) return null;
          final song = songs[index];
          final isPlaying = widget.currentSong?.id == song.id;
          final isExpanded = widget.controller.expandedSongId == song.id;

          return LibraryTrackListItem(
            song: song,
            isPlaying: isPlaying,
            isExpanded: isExpanded,
            onTap: () => widget.onSongTap(song, queue: album.songs),
            onToggleExpanded: () => widget.controller
                .updateExpandedSongId(isExpanded ? null : song.id),
            onVerify: () => widget.onVerifySong(song),
            onOpenFolder: () => widget.onOpenFolder(song.filePath),
          );
        },
        childCount: songs.length,
      ),
    );
  }

  List<Widget> _buildDiscGroupedTrackList(
    Album album,
    Map<String, List<Song>> discGroups,
    String filter,
  ) {
    final slivers = <Widget>[];

    for (final entry in discGroups.entries) {
      var songs = entry.value;
      if (filter.isNotEmpty) {
        songs = songs
            .where((song) => LibraryUtils.matchesSongQuery(song, filter))
            .toList();
      }

      if (songs.isEmpty) continue;

      final discLabel = LibraryUtils.getDiscLabel(entry.key);

      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                bottom:
                    BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.album,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  discLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${songs.length} tracks)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final song = songs[index];
              final isPlaying = widget.currentSong?.id == song.id;
              final isExpanded = widget.controller.expandedSongId == song.id;

              return LibraryTrackListItem(
                song: song,
                isPlaying: isPlaying,
                isExpanded: isExpanded,
                onTap: () => widget.onSongTap(song, queue: album.songs),
                onToggleExpanded: () => widget.controller
                    .updateExpandedSongId(isExpanded ? null : song.id),
                onVerify: () => widget.onVerifySong(song),
                onOpenFolder: () => widget.onOpenFolder(song.filePath),
              );
            },
            childCount: songs.length,
          ),
        ),
      );

      if (entry != discGroups.entries.last) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
      }
    }

    return slivers;
  }
}
