import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../../models/song.dart';
import '../../utils/library_utils.dart';
import '../technical_details_helper.dart';

class LibraryTrackListItem extends StatefulWidget {
  const LibraryTrackListItem({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.isExpanded,
    required this.onTap,
    required this.onToggleExpanded,
    required this.onVerify,
    required this.onOpenFolder,
  });

  final Song song;
  final bool isPlaying;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onToggleExpanded;
  final VoidCallback onVerify;
  final VoidCallback onOpenFolder;

  @override
  State<LibraryTrackListItem> createState() => _LibraryTrackListItemState();
}

class _LibraryTrackListItemState extends State<LibraryTrackListItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _soundwaveController;

  @override
  void initState() {
    super.initState();
    _soundwaveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    if (widget.isPlaying) {
      _soundwaveController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LibraryTrackListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _soundwaveController.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _soundwaveController.stop();
    }
  }

  @override
  void dispose() {
    _soundwaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: widget.isPlaying
                  ? AppColors.purple.withOpacity(0.15)
                  : _isHovered
                      ? AppColors.darkGray.withOpacity(0.5)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 36,
                alignment: Alignment.center,
                child: widget.isPlaying
                    ? Icon(
                        Icons.volume_up,
                        color: AppColors.purple,
                        size: 20,
                      )
                    : _isHovered
                        ? Icon(
                            Icons.play_circle_filled,
                            color: AppColors.purple,
                            size: 24,
                          )
                        : Text(
                            widget.song.trackNumber
                                    ?.toString()
                                    .padLeft(2, '0') ??
                                '–',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.lightGray,
                            ),
                          ),
              ),
              title: Text(
                widget.song.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      widget.isPlaying ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isPlaying ? AppColors.purple : AppColors.white,
                ),
              ),
              subtitle: Text(
                LibraryUtils.audioDetailsSummary(widget.song),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.gray,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRatingDisplay(),
                  if (_isHovered) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        widget.isExpanded ? Icons.info : Icons.info_outline,
                        size: 16,
                      ),
                      iconSize: 16,
                      color:
                          widget.isExpanded ? AppColors.purple : AppColors.gray,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                      tooltip:
                          widget.isExpanded ? 'Hide details' : 'Show details',
                      onPressed: widget.onToggleExpanded,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      iconSize: 16,
                      color: AppColors.gray,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                      tooltip: 'Verify audio quality',
                      onPressed: widget.onVerify,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.folder_open, size: 16),
                      iconSize: 16,
                      color: AppColors.gray,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                      tooltip: 'Open file location',
                      onPressed: widget.onOpenFolder,
                    ),
                  ],
                  if (widget.song.duration != null || widget.isPlaying)
                    const SizedBox(width: 12),
                  if (widget.song.duration != null) ...[
                    Text(
                      LibraryUtils.formatDuration(widget.song.duration!),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.gray,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (widget.isPlaying)
                    AnimatedBuilder(
                      animation: _soundwaveController,
                      builder: (context, child) => Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildSoundwaveBar(
                              0.4 + (_soundwaveController.value * 0.5)),
                          const SizedBox(width: 3),
                          _buildSoundwaveBar(
                              0.9 - (_soundwaveController.value * 0.6)),
                          const SizedBox(width: 3),
                          _buildSoundwaveBar(
                              0.5 + (_soundwaveController.value * 0.4)),
                        ],
                      ),
                    ),
                ],
              ),
              onTap: widget.onTap,
            ),
          ),
          if (widget.isExpanded) _buildExpandedDetailPanel(),
        ],
      ),
    );
  }

  Widget _buildSoundwaveBar(double heightFactor) {
    return Container(
      width: 3,
      height: 14 * heightFactor,
      decoration: BoxDecoration(
        color: AppColors.purple,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildRatingDisplay() {
    final songPath = widget.song.filePath;
    final isFavorite = favoritesService.isFavorite(songPath);
    final rating = favoritesService.getRating(songPath);

    if (!isFavorite && rating == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFavorite) ...[
          Icon(
            Icons.favorite,
            color: Colors.red.withOpacity(0.8),
            size: 14,
          ),
          const SizedBox(width: 4),
        ],
        if (rating > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              rating,
              (index) => const Icon(
                Icons.star,
                color: Color(0xFFFFC107),
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedDetailPanel() {
    return Container(
      margin: const EdgeInsets.only(left: 28, right: 28, bottom: 8, top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.purple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Details',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(height: 8),
          TechnicalDetailsHelper.buildInfoRow(
              'Format', widget.song.format ?? 'Unknown'),
          if (widget.song.bitDepth != null && widget.song.sampleRate != null)
            TechnicalDetailsHelper.buildInfoRow(
              'Quality',
              '${widget.song.bitDepth}-bit / ${widget.song.sampleRate! ~/ 1000} kHz${widget.song.isEstimated ? " (est.)" : ""}',
            ),
          if (widget.song.channels != null || widget.song.channelLayout != null)
            TechnicalDetailsHelper.buildInfoRow(
              'Channels',
              TechnicalDetailsHelper.formatChannels(
                widget.song.channelLayout,
                widget.song.channels,
              ),
            ),
          if (widget.song.codecDetails != null)
            TechnicalDetailsHelper.buildInfoRow(
                'Codec', widget.song.codecDetails!),
          if (widget.song.bitrate != null)
            TechnicalDetailsHelper.buildInfoRow(
              'Bitrate',
              '${widget.song.bitrate} kbps${widget.song.isEstimated ? " (est.)" : ""}',
            ),
          if (widget.song.fileSize != null)
            TechnicalDetailsHelper.buildInfoRow(
              'File Size',
              widget.song.fileSizeDisplay ?? 'Unknown',
            ),
          TechnicalDetailsHelper.buildInfoRow(
            'Type',
            widget.song.isLossless ? 'Lossless' : 'Lossy',
          ),
          const SizedBox(height: 8),
          TechnicalDetailsHelper.buildClickablePathRow(
              'Path', widget.song.filePath),
        ],
      ),
    );
  }
}
