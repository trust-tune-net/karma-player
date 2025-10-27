import 'dart:io';
import 'package:flutter/material.dart';
import '../services/playback_service.dart';

class NowPlayingScreen extends StatelessWidget {
  final PlaybackService playbackService;

  const NowPlayingScreen({
    super.key,
    required this.playbackService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playbackService,
      builder: (context, _) {
        final song = playbackService.currentSong;
        final isPlaying = playbackService.isPlaying;
        final position = playbackService.position;
        final duration = playbackService.duration;

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
            title: const Text('Now Playing'),
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
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            // Album artwork with enhanced styling
                            Container(
                              width: 320,
                              height: 320,
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
                            const SizedBox(height: 48),

                            // Song info
                            Text(
                              song.title,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFFFFFF),
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              song.artist,
                              style: const TextStyle(
                                fontSize: 20,
                                color: Color(0xFFA855F7),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (song.album?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 10),
                              Text(
                                song.album!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF999999),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 56),

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
                                        playbackService.seek(newPosition);
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
                            const SizedBox(height: 48),

                            // Player controls with hover effects
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _HoverableControlButton(
                                  icon: Icons.skip_previous_rounded,
                                  onPressed: playbackService.playPrevious,
                                ),
                                const SizedBox(width: 32),
                                _PlayPauseButton(
                                  isPlaying: isPlaying,
                                  onPressed: playbackService.togglePlayPause,
                                ),
                                const SizedBox(width: 32),
                                _HoverableControlButton(
                                  icon: Icons.skip_next_rounded,
                                  onPressed: playbackService.playNext,
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
