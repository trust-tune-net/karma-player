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

                            // Album artwork
                            Container(
                              width: 280,
                              height: 280,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: song.artworkPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(song.artworkPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.album,
                                    size: 160,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.3),
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.album,
                              size: 160,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                            ),
                    ),
                    const SizedBox(height: 40),

                    // Song info
                    Text(
                      song.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
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
                      const SizedBox(height: 8),
                      Text(
                        song.album!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF888888),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 50),

                    // Progress bar and time
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4.0,
                              activeTrackColor: const Color(0xFFA855F7),
                              inactiveTrackColor: const Color(0xFF3A3A3E),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7.0,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14.0,
                              ),
                              thumbColor: const Color(0xFFA855F7),
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
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF888888),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Player controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          iconSize: 40,
                          color: const Color(0xFFCCCCCC),
                          onPressed: playbackService.playPrevious,
                        ),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFA855F7),
                          ),
                          child: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            ),
                            iconSize: 40,
                            color: Colors.white,
                            onPressed: playbackService.togglePlayPause,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          iconSize: 40,
                          color: const Color(0xFFCCCCCC),
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
