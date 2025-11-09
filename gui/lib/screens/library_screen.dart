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
import '../widgets/library/library_files_view.dart';
import '../widgets/common/primary_screen_header.dart';

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
      appBar: PrimaryScreenHeader(
        title: 'Library',
        trailing: Align(
          alignment: Alignment.centerRight,
          child: StatsBadges(
            onConnectionTap: _controller.checkHealth,
          ),
        ),
        bottom: _buildControlSection(context),
      ),
      body: Column(
        children: [
          if (_controller.statusMessage.isNotEmpty) _buildStatusBanner(context),
          Expanded(
            child: _controller.viewMode == LibraryViewMode.albums
                ? LibraryAlbumGrid(
                    controller: _controller,
                    onAlbumSelected: (album) {
                      _controller.selectAlbum(album);
                      _albumTrackFilterController.clear();
                    },
                  )
                : LibraryFilesView(
                    controller: _controller,
                    songs: _controller.displaySongs,
                    currentSong: widget.currentSong,
                    onSongTap: (song) => _handleFileSongTap(song),
                    onVerifySong: _verifySongQuality,
                    onOpenFolder: _openFileLocation,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _controller.isMetadataScanRunning
          ? _buildMetadataScanPanel(context)
          : null,
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          if (_controller.isScanning)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (_controller.isScanning) const SizedBox(width: 12),
          Expanded(
            child: Text(
              _controller.statusMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildControlSection(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(124),
      child: Container(
        color: const Color(0xFF090909),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildSearchField(context)),
                const SizedBox(width: 18),
                _buildSortMenu(context),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRefreshChip(context),
                const SizedBox(width: 12),
                _buildScanMetadataChip(context),
                const SizedBox(width: 12),
                _buildViewToggle(context),
                const SizedBox(width: 18),
                Expanded(child: _buildFormatFilters(context)),
              ],
            ),
          ],
        ),
      ),
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
        controller: _searchController,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: 'Search albums, artists, or songs...',
          hintStyle:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF888888)),
          prefixIcon:
              const Icon(Icons.search, size: 20, color: Color(0xFF888888)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  color: const Color(0xFF888888),
                  onPressed: () {
                    _searchController.clear();
                    _controller.updateSearchQuery('');
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
    final sortCriteria = _controller.sortCriteria;
    final sortAscending = _controller.sortAscending;

    final trackLabel =
        _controller.viewMode == LibraryViewMode.files ? 'Album' : 'Tracks';

    String label;
    switch (sortCriteria) {
      case SortCriteria.title:
        label = 'Title';
        break;
      case SortCriteria.artist:
        label = 'Artist';
        break;
      case SortCriteria.trackCount:
        label = trackLabel;
        break;
      case SortCriteria.year:
        label = 'Year';
        break;
    }

    return _SortChip(
      label: label,
      ascending: sortAscending,
      onToggleDirection: _controller.toggleSortOrder,
      onSelect: (criteria) {
        _controller.updateSortCriteria(criteria);
      },
      trackLabel: trackLabel,
      selected: true,
    );
  }

  Widget _buildRefreshChip(BuildContext context) {
    final isScanning = _controller.isScanning;
    final textColor =
        isScanning ? const Color(0xFF888888) : const Color(0xFFA855F7);
    final backgroundColor = isScanning
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFA855F7).withOpacity(0.15);
    final borderColor = isScanning
        ? const Color(0xFF333333)
        : const Color(0xFFA855F7).withOpacity(0.4);

    return GestureDetector(
      onTap: isScanning ? null : _controller.refreshLibrary,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isScanning)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            else
              Icon(
                Icons.refresh,
                size: 16,
                color: textColor,
              ),
            const SizedBox(width: 6),
            Text(
              isScanning ? 'Refreshing…' : 'Refresh',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanMetadataChip(BuildContext context) {
    final isRunning = _controller.isMetadataScanRunning;
    final isDisabled = isRunning || !_controller.hasFiles;
    final textColor = isDisabled
        ? const Color(0xFF888888)
        : const Color(0xFF36CFC9); // teal accent
    final backgroundColor = isDisabled
        ? const Color(0xFF1E1E1E)
        : const Color(0xFF36CFC9).withOpacity(0.15);
    final borderColor = isDisabled
        ? const Color(0xFF333333)
        : const Color(0xFF36CFC9).withOpacity(0.4);

    return GestureDetector(
      onTap: isDisabled ? null : () => _controller.scanAllMetadata(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRunning)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            else
              Icon(
                Icons.graphic_eq,
                size: 16,
                color: textColor,
              ),
            const SizedBox(width: 6),
            Text(
              isRunning ? 'Scanning…' : 'Scan Metadata',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatFilters(BuildContext context) {
    final formats = _controller.availableFormats.toList()..sort();

    if (formats.isEmpty && !_controller.hasActiveFormatFilter) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_controller.hasActiveFormatFilter)
          ActionChip(
            label: const Text('Clear format filters'),
            onPressed: _controller.clearFormatFilters,
            avatar: const Icon(Icons.clear, size: 16),
          ),
        ...formats.map(
          (format) => FilterChip(
            selected: _controller.selectedFormats.contains(format),
            label: Text('$format (${_controller.formatCount(format)})'),
            onSelected: (_) => _controller.toggleFormatSelection(format),
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    final viewMode = _controller.viewMode;

    Widget buildSegment({
      required LibraryViewMode mode,
      required IconData icon,
      required String label,
      BorderRadius? radius,
    }) {
      final isActive = viewMode == mode;
      return InkWell(
        borderRadius: radius,
        onTap: () => _controller.updateViewMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFA855F7).withOpacity(0.2)
                : Colors.transparent,
            borderRadius: radius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? const Color(0xFFA855F7)
                    : const Color(0xFF888888),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? const Color(0xFFA855F7)
                      : const Color(0xFF888888),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildSegment(
            mode: LibraryViewMode.albums,
            icon: Icons.grid_view,
            label: 'Albums',
            radius: const BorderRadius.only(
              topLeft: Radius.circular(19),
              bottomLeft: Radius.circular(19),
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: const Color(0xFF333333),
          ),
          buildSegment(
            mode: LibraryViewMode.files,
            icon: Icons.list,
            label: 'Files',
            radius: const BorderRadius.only(
              topRight: Radius.circular(19),
              bottomRight: Radius.circular(19),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFileSongTap(Song song) async {
    final updatedSong = await _controller.ensureSongMetadata(song);
    widget.onSongTap(
      updatedSong,
      queue: _controller.displaySongs,
    );
  }

  Widget _buildMetadataScanPanel(BuildContext context) {
    final completed = _controller.metadataScanCompleted;
    final total = _controller.metadataScanTotal;
    if (total == 0) {
      return const SizedBox.shrink();
    }

    final progress = _controller.metadataScanProgress.clamp(0.0, 1.0);
    final currentSong = _controller.metadataScanCurrentSong;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          border: Border(
            top: BorderSide(color: Color(0xFF2B2B2B), width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.graphic_eq,
                    size: 20, color: Color(0xFF36CFC9)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scanning metadata ($completed / $total)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (currentSong != null)
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFCCCCCC),
                          ),
                        ),
                      Text(
                        'Refreshing tags may briefly reorder songs while running.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _controller.isMetadataScanRunning
                      ? _controller.cancelMetadataScan
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF36CFC9),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.isNaN ? null : progress,
                minHeight: 6,
                backgroundColor: const Color(0xFF1F1F1F),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF36CFC9)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatefulWidget {
  const _SortChip({
    required this.label,
    required this.ascending,
    required this.onToggleDirection,
    required this.onSelect,
    required this.trackLabel,
    required this.selected,
  });

  final String label;
  final bool ascending;
  final VoidCallback onToggleDirection;
  final ValueChanged<SortCriteria> onSelect;
  final String trackLabel;
  final bool selected;

  @override
  State<_SortChip> createState() => _SortChipState();
}

class _SortChipState extends State<_SortChip> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isMenuOpen = true;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
      });
    }
  }

  OverlayEntry _buildOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _removeOverlay,
          child: Stack(
            children: [
              Positioned(
                width: size.width,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  offset: Offset(0, size.height + 8),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF333333)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMenuItem(
                            label: 'Title',
                            criteria: SortCriteria.title,
                          ),
                          _buildMenuItem(
                            label: 'Artist',
                            criteria: SortCriteria.artist,
                          ),
                          _buildMenuItem(
                            label: widget.trackLabel,
                            criteria: SortCriteria.trackCount,
                          ),
                          _buildMenuItem(
                            label: 'Year',
                            criteria: SortCriteria.year,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required String label,
    required SortCriteria criteria,
  }) {
    final isSelected = widget.label == label;
    return InkWell(
      onTap: () {
        widget.onSelect(criteria);
        _removeOverlay();
      },
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF333333),
              width: criteria == SortCriteria.year ? 0 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Icon(Icons.check, size: 16, color: Color(0xFFA855F7))
            else
              const SizedBox(width: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFFA855F7)
                    : const Color(0xFFDDDDDD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = widget.selected
        ? const Color(0xFFA855F7).withOpacity(0.15)
        : const Color(0xFF1E1E1E);
    final borderColor = widget.selected
        ? const Color(0xFFA855F7).withOpacity(0.4)
        : const Color(0xFF333333);
    final textColor =
        widget.selected ? const Color(0xFFA855F7) : const Color(0xFFDDDDDD);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggleMenu,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sort,
                    size: 16,
                    color: textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.rotate(
                    angle: _isMenuOpen ? 3.1416 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onToggleDirection,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor),
              ),
              child: Icon(
                widget.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
