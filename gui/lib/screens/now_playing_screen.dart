import 'dart:io';
import 'package:flutter/material.dart';
import '../services/playback_service.dart';
import '../main.dart';

class NowPlayingScreen extends StatefulWidget {
  final PlaybackService playbackService;

  const NowPlayingScreen({
    super.key,
    required this.playbackService,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: widget.playbackService,
        builder: (context, _) {
          final song = widget.playbackService.currentSong;
        final isPlaying = widget.playbackService.isPlaying;
        final position = widget.playbackService.position;
        final duration = widget.playbackService.duration;
        final repeatMode = widget.playbackService.repeatMode;
        final isShuffle = widget.playbackService.isShuffle;

        if (song == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Now Playing'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_note_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No song playing',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a song from your library',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Now Playing'),
                const Spacer(),
                // #7 Favorite & Rating - Top Bar (aligned)
                Builder(
                  builder: (context) {
                    final songKey = song.filePath;
                    final isFavorite = favoritesService.isFavorite(songKey);
                    final rating = favoritesService.getRating(songKey);

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Favorite heart button
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : const Color(0xFF888888),
                          ),
                          iconSize: 22,
                          onPressed: () {
                            favoritesService.toggleFavorite(songKey);
                            setState(() {}); // Rebuild
                          },
                          tooltip: 'Favorite',
                        ),
                        // Star rating (0-5)
                        ...List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: index < rating ? const Color(0xFFFFC107) : const Color(0xFF888888),
                            ),
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () {
                              favoritesService.setRating(songKey, index + 1);
                              setState(() {}); // Rebuild
                            },
                          );
                        }),
                      ],
                    );
                  }
                ),
              ],
            ),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Album artwork with enhanced styling
                                Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFA855F7).withOpacity(0.3),
                                        blurRadius: 40,
                                        spreadRadius: 5,
                                        offset: const Offset(0, 10),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: song.artworkPath != null
                                        ? Image.file(
                                            File(song.artworkPath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: const Color(0xFF2A2A2E),
                                                child: Icon(
                                                  Icons.album,
                                                  size: 160,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.3),
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: const Color(0xFF2A2A2E),
                                            child: Icon(
                                              Icons.album,
                                              size: 160,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // #1 Audio Quality Badge
                                if (song.format != null)
                                  _AudioQualityBadge(song: song),
                                if (song.format != null)
                                  const SizedBox(height: 16),

                                // Song info
                                Text(
                                  song.title,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFFFFFF),
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  song.artist,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFFA855F7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (song.album?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    song.album!,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF999999),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: 16),

                                // Progress bar and time
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Column(
                                    children: [
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 5.0,
                                          activeTrackColor: const Color(0xFFA855F7),
                                          inactiveTrackColor: const Color(0xFF3A3A3E),
                                          thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 8.0,
                                          ),
                                          overlayShape: const RoundSliderOverlayShape(
                                            overlayRadius: 16.0,
                                          ),
                                          thumbColor: Colors.white,
                                          overlayColor: const Color(0xFFA855F7).withOpacity(0.2),
                                        ),
                                        child: Slider(
                                          value: duration.inMilliseconds > 0
                                              ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                                              : 0.0,
                                          onChanged: (value) {
                                            final newPosition = Duration(
                                              milliseconds: (value * duration.inMilliseconds).round(),
                                            );
                                            widget.playbackService.seek(newPosition);
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatDuration(position),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF888888),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              _formatDuration(duration),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF888888),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Player controls with hover effects
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _HoverableControlButton(
                                      icon: Icons.skip_previous_rounded,
                                      onPressed: widget.playbackService.playPrevious,
                                    ),
                                    const SizedBox(width: 32),
                                    _PlayPauseButton(
                                      isPlaying: isPlaying,
                                      onPressed: widget.playbackService.togglePlayPause,
                                    ),
                                    const SizedBox(width: 32),
                                    _HoverableControlButton(
                                      icon: Icons.skip_next_rounded,
                                      onPressed: widget.playbackService.playNext,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          );
        },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '$minutes:${twoDigits(seconds)}';
    }
  }
}

// #1 Audio Quality Badge Widget
class _AudioQualityBadge extends StatelessWidget {
  final dynamic song;

  const _AudioQualityBadge({required this.song});

  @override
  Widget build(BuildContext context) {
    final format = song.format ?? 'UNKNOWN';
    final isLossless = song.isLossless ?? false;
    final qualityDisplay = song.qualityDisplay; // e.g., "24/192"

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isLossless
          ? const Color(0xFF10B981).withOpacity(0.2)
          : const Color(0xFFFFA500).withOpacity(0.2),
        border: Border.all(
          color: isLossless
            ? const Color(0xFF10B981)
            : const Color(0xFFFFA500),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLossless ? Icons.high_quality : Icons.music_note,
            color: isLossless
              ? const Color(0xFF10B981)
              : const Color(0xFFFFA500),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            format,
            style: TextStyle(
              color: isLossless
                ? const Color(0xFF10B981)
                : const Color(0xFFFFA500),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (qualityDisplay != null) ...[
            const SizedBox(width: 8),
            Text(
              qualityDisplay,
              style: TextStyle(
                color: isLossless
                  ? const Color(0xFF10B981)
                  : const Color(0xFFFFA500),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Hoverable control button widget for previous/next
class _HoverableControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _HoverableControlButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_HoverableControlButton> createState() => _HoverableControlButtonState();
}

class _HoverableControlButtonState extends State<_HoverableControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHovered
                ? const Color(0xFF3A3A3E)
                : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: 40,
            color: _isHovered
                ? const Color(0xFFA855F7)
                : const Color(0xFFAAAAAA),
          ),
        ),
      ),
    );
  }
}

// Enhanced play/pause button with hover effect
class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFA855F7),
            boxShadow: _isHovered ? [
              BoxShadow(
                color: const Color(0xFFA855F7).withOpacity(0.6),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ] : [
              BoxShadow(
                color: const Color(0xFFA855F7).withOpacity(0.3),
                blurRadius: 16,
              ),
            ],
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
