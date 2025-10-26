import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/song.dart';
import 'models/album.dart';
import 'models/torrent.dart' as torrent_model;
import 'services/transmission_client.dart';
import 'services/daemon_manager.dart';
import 'services/app_settings.dart';
import 'widgets/status_bar.dart';
import 'widgets/diagnostics_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'services/playback_service.dart';
import 'screens/now_playing_screen.dart';
import 'screens/search_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/settings_screen.dart';

// App Color Palette (like Melo)
class AppColors {
  // Primary brand
  static const purple = Color(0xFFA855F7);
  static const purpleLight = Color(0xFF8B5CF6);

  // Accent colors
  static const orange = Color(0xFFFF6B4A); // CTA buttons, like Melo's Upgrade
  static const green = Color(0xFF10B981); // Success states
  static const red = Color(0xFFEF4444); // Errors, delete
  static const amber = Color(0xFFF59E0B); // Warnings

  // Neutrals
  static const black = Color(0xFF000000);
  static const darkestGray = Color(0xFF0A0A0A);
  static const darkerGray = Color(0xFF1C1C1E);
  static const darkGray = Color(0xFF2A2A2E);
  static const gray = Color(0xFF666666);
  static const lightGray = Color(0xFF888888);
  static const lighterGray = Color(0xFFAAAAAA);
  static const white = Color(0xFFFFFFFF);
}

// Global instances
final appSettings = AppSettings();
final daemonManager = DaemonManager();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Load settings
  await appSettings.load();

  // Start transmission daemon on app launch
  print('Starting transmission daemon...');
  final started = await daemonManager.startDaemon(customDownloadDir: appSettings.customDownloadDir);
  if (started) {
    print('Transmission daemon started successfully');
  } else {
    print('Warning: Failed to start transmission daemon');
  }

  runApp(const KarmaPlayerApp());
}

class KarmaPlayerApp extends StatelessWidget {
  const KarmaPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karma Player',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFA855F7), // Vibrant purple
          secondary: const Color(0xFF8B5CF6),
          surface: const Color(0xFF1C1C1E),
          background: const Color(0xFF000000),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFFFFFFFF),
          onBackground: const Color(0xFFFFFFFF),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF000000),
        fontFamily: GoogleFonts.inter().fontFamily, // Use Inter font like Melo
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          iconTheme: IconThemeData(
            color: Color(0xFFA855F7),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1C1C1E),
          elevation: 0, // Flat design
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFFFF),
            height: 1.2,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFFFFF),
            height: 1.3,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFA855F7),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Color(0xFFAAAAAA),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Color(0xFF888888),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// Reusable stats badges widget for AppBar
// Uses ListenableBuilder to rebuild when appSettings changes (ChangeNotifier)
class StatsBadges extends StatelessWidget {
  final VoidCallback? onConnectionTap; // Callback for connection badge tap

  const StatsBadges({
    super.key,
    this.onConnectionTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Listen to appSettings changes and rebuild automatically
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, child) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: screenWidth > 1200 ? 32 : 20),

        // Albums count badge (from global state)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.album, size: 14, color: AppColors.purple.withOpacity(0.8)),
              const SizedBox(width: 5),
              Text(
                '${appSettings.albumCount}',
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Total plays badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_outline, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 5),
              Text(
                '${appSettings.totalPlays}',
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Downloaded GB badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download_outlined, size: 14, color: Color(0xFF3B82F6)),
              const SizedBox(width: 5),
              Text(
                '${appSettings.downloadedGigabytes} GB',
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Connection badge (clickable)
        InkWell(
          onTap: onConnectionTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: appSettings.connectionBadge.$1.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: appSettings.connectionBadge.$1.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: appSettings.connectionBadge.$1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  appSettings.connectionBadge.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: appSettings.connectionBadge.$1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;

  // Centralized playback service (single source of truth)
  final PlaybackService _playbackService = PlaybackService();

  // Animation for soundwave
  late AnimationController _soundwaveController;

  // Global key to access LibraryScreen state
  final GlobalKey<_LibraryScreenState> _libraryKey = GlobalKey<_LibraryScreenState>();

  @override
  void initState() {
    super.initState();

    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Initialize soundwave animation controller
    _soundwaveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    // Listen to playback service changes for animation control
    _playbackService.addListener(() {
      // Control animation based on playing state
      if (_playbackService.isPlaying) {
        _soundwaveController.repeat(reverse: true);
      } else {
        _soundwaveController.stop();
      }
    });
  }

  @override
  void dispose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    _soundwaveController.dispose();
    _playbackService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Stop player when app is being terminated or going to background
    // This ensures MPV shuts down cleanly before the app process is killed
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      _playbackService.player.pause();
    }
  }

  // Wrapper methods to integrate with PlaybackService
  void _playSong(Song song, {List<Song>? queue, bool? isShuffled}) {
    _playbackService.playSong(song, queue: queue, isShuffled: isShuffled ?? false);
    // Track play count
    appSettings.incrementPlays();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Main content with sidebar
          Expanded(
            child: Row(
              children: [
                // Left Sidebar Navigation (like Melo)
                Container(
                  width: 220,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A0A0A),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo/App Name - Banksy Style
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TTN Stencil Graffiti Style
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Stencil-style TTN
                                  Text(
                                    'TTN',
                                    style: TextStyle(
                                      fontFamily: 'Impact',
                                      fontSize: 56,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 8.0,
                                      height: 0.85,
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(4, 4),
                                          blurRadius: 0,
                                          color: const Color(0xFFA855F7).withOpacity(0.7),
                                        ),
                                        Shadow(
                                          offset: const Offset(8, 8),
                                          blurRadius: 0,
                                          color: Colors.black.withOpacity(0.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Network name - spray paint style
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TRUST TUNE',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withOpacity(0.95),
                                    letterSpacing: 2.2,
                                    height: 1.3,
                                  ),
                                ),
                                Text(
                                  'NETWORK',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFA855F7).withOpacity(0.9),
                                    letterSpacing: 2.2,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Navigation items
                      _buildNavItem(
                        icon: Icons.library_music_outlined,
                        selectedIcon: Icons.library_music,
                        label: 'Library',
                        index: 0,
                      ),
                      _buildNavItem(
                        icon: Icons.search_outlined,
                        selectedIcon: Icons.search,
                        label: 'Search',
                        index: 1,
                      ),
                      _buildNavItem(
                        icon: Icons.download_outlined,
                        selectedIcon: Icons.download,
                        label: 'Downloads',
                        index: 2,
                      ),
                      _buildNavItem(
                        icon: Icons.play_circle_outline,
                        selectedIcon: Icons.play_circle,
                        label: 'Now Playing',
                        index: 3,
                      ),

                      const Spacer(),

                      // Settings at very bottom
                      _buildNavItem(
                        icon: Icons.settings_outlined,
                        selectedIcon: Icons.settings,
                        label: 'Settings',
                        index: 4,
                      ),

                      const SizedBox(height: 16), // Minimal space for player bar
                    ],
                  ),
                ),

                // Main content area
                Expanded(
                  child: ListenableBuilder(
                    listenable: _playbackService,
                    builder: (context, _) {
                      return IndexedStack(
                        index: _selectedIndex,
                        children: [
                          LibraryScreen(key: _libraryKey, onSongTap: _playSong, currentSong: _playbackService.currentSong),
                          const SearchScreen(),
                          const DownloadsScreen(),
                          NowPlayingScreen(playbackService: _playbackService),
                          const SettingsScreen(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Full-width player bar at bottom (like Spotify/Melo)
          _buildPlayerBar(context),
        ],
      ),
    );
  }

  // Sidebar navigation item
  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              // If clicking Library (index 0) and already on Library, reset to albums view
              if (index == 0 && _selectedIndex == 0) {
                _libraryKey.currentState?.resetToAlbumsView();
              }
              _selectedIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1A1A1A)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: const Color(0xFFA855F7).withOpacity(0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 20,
                  color: isSelected
                      ? const Color(0xFFA855F7)
                      : const Color(0xFF888888),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF888888),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Full-width player bar (like Melo/Spotify)
  Widget _buildPlayerBar(BuildContext context) {
    return ListenableBuilder(
      listenable: _playbackService,
      builder: (context, _) {
        final currentSong = _playbackService.currentSong;
        if (currentSong == null) return const SizedBox.shrink();

        final position = _playbackService.position;
        final duration = _playbackService.duration;
        final isPlaying = _playbackService.isPlaying;
        final queue = _playbackService.queue;
        final isShuffle = _playbackService.isShuffle;
        final repeatMode = _playbackService.repeatMode;
        final volume = _playbackService.volume;

        print('[PLAYER BAR] Building with isShuffle=$isShuffle, queue=${queue.length}');

        return Container(
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
          ),
          child: Column(
            children: [
              // Progress bar
              SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0,
                  backgroundColor: const Color(0xFF2A2A2E),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),

          // Player controls - responsive layout
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final showVolumePercentage = width > 700;
                final showShuffleRepeat = width > 600;
                final showVolumeSlider = width > 500;
                final trackInfoWidth = width > 800 ? 200.0 : (width > 600 ? 150.0 : 120.0);
                final volumeSliderWidth = showVolumePercentage ? 120.0 : 80.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Album artwork
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: currentSong.artworkPath != null
                              ? Image.file(
                                  File(currentSong.artworkPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.music_note,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.music_note,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Track info - responsive width
                      SizedBox(
                        width: trackInfoWidth,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentSong.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Playback controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            iconSize: 24,
                            color: queue.length > 1
                                ? const Color(0xFFAAAAAA)
                                : const Color(0xFF444444),
                            onPressed: queue.length > 1 ? _playbackService.playPrevious : null,
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _playbackService.togglePlayPause,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              child: AnimatedBuilder(
                                animation: _soundwaveController,
                                builder: (context, child) {
                                  return isPlaying
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            _buildSoundwaveBar(0.4 + (_soundwaveController.value * 0.5)),
                                            const SizedBox(width: 3),
                                            _buildSoundwaveBar(0.9 - (_soundwaveController.value * 0.6)),
                                            const SizedBox(width: 3),
                                            _buildSoundwaveBar(0.5 + (_soundwaveController.value * 0.4)),
                                          ],
                                        )
                                      : const Icon(
                                          Icons.play_arrow,
                                          size: 20,
                                          color: Colors.white,
                                        );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            iconSize: 24,
                            color: queue.length > 1
                                ? const Color(0xFFAAAAAA)
                                : const Color(0xFF444444),
                            onPressed: queue.length > 1 ? _playbackService.playNext : null,
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Time display
                      Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF888888),
                        ),
                      ),

                      // Shuffle and repeat buttons - hide on small screens
                      if (showShuffleRepeat) ...[
                        const SizedBox(width: 24),

                        // Shuffle button
                        IconButton(
                          icon: const Icon(Icons.shuffle),
                          iconSize: 20,
                          color: isShuffle ? AppColors.purple : const Color(0xFFAAAAAA),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onPressed: queue.length > 1 ? _playbackService.toggleShuffle : null,
                        ),

                        // Repeat button
                        IconButton(
                          icon: Icon(
                            repeatMode == RepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                          ),
                          iconSize: 20,
                          color: repeatMode != RepeatMode.off
                              ? AppColors.purple
                              : const Color(0xFFAAAAAA),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onPressed: queue.length > 0 ? _playbackService.toggleRepeatMode : null,
                        ),
                      ],

                      // Volume control - hide on very small screens
                      if (showVolumeSlider) ...[
                        const SizedBox(width: 8),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                volume == 0
                                    ? Icons.volume_off_outlined
                                    : volume < 0.5
                                        ? Icons.volume_down_outlined
                                        : Icons.volume_up_outlined,
                              ),
                              iconSize: 20,
                              color: const Color(0xFFAAAAAA),
                              onPressed: () {
                                // Toggle mute
                                _playbackService.setVolume(volume == 0 ? 0.5 : 0);
                              },
                            ),
                            SizedBox(
                              width: volumeSliderWidth,
                              child: Slider(
                                value: volume,
                                onChanged: _playbackService.setVolume,
                                activeColor: AppColors.purple,
                                inactiveColor: const Color(0xFF3A3A3E),
                              ),
                            ),
                            if (showVolumePercentage) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${(volume * 100).round()}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF888888),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }

  Widget _buildSoundwaveBar(double heightFactor) {
    return Container(
      width: 4,
      height: 20 * heightFactor,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// LIBRARY SCREEN
class LibraryScreen extends StatefulWidget {
  final Function(Song song, {List<Song>? queue, bool? isShuffled}) onSongTap;
  final Song? currentSong;

  const LibraryScreen({super.key, required this.onSongTap, this.currentSong});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Album> _albums = [];
  bool _isScanning = false;
  String _statusMessage = 'No music loaded';
  Album? _selectedAlbum;
  Map<String, double> _downloadProgress = {}; // Maps album names to progress
  Timer? _downloadPollTimer;
  Timer? _autoRefreshTimer; // Auto-refresh library every 10 minutes
  late final TransmissionClient _transmissionClient;

  @override
  void initState() {
    super.initState();
    _transmissionClient = TransmissionClient(baseUrl: appSettings.transmissionRpcUrl);
    _scanMusicFolder();
    // Poll downloads every 2 seconds
    _downloadPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadDownloads());
    // Auto-refresh library and connection badge every 10 minutes
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      print('🔄 Auto-refresh: Scanning library and checking connection...');
      _scanMusicFolder(); // This also calls _checkHealth() at the end
    });
    // Check internet health only once on startup
    _checkHealth();
  }

  @override
  void dispose() {
    _downloadPollTimer?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    // appSettings.checkApiHealth() calls notifyListeners()
    // which automatically updates all StatsBadges via ListenableBuilder
    await appSettings.checkApiHealth();
  }

  Future<void> _loadDownloads() async {
    try {
      // Get all active torrents from transmission
      final torrents = await _transmissionClient.getTorrents();

      // Map torrent names to album names and update progress
      final newProgress = <String, double>{};

      for (final torrent in torrents) {
        final torrentName = torrent.name;
        final progress = torrent.percentDone.toDouble();

        // Track completed torrents for statistics
        if (progress >= 1.0) {
          // Use global settings to track completions (prevents duplicate logging)
          if (!appSettings.completedTorrentIds.contains(torrent.id)) {
            // This is a newly completed torrent - add its size to stats
            await appSettings.addDownloadedBytes(torrent.totalSize, torrent.id);
            print('Download completed: ${torrent.name} (${(torrent.totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB)');

            // Trigger library refresh to show newly downloaded music
            print('🔄 Download complete: Refreshing library...');
            _scanMusicFolder(); // This also updates connection badge
          }
          // Skip showing progress for completed torrents
          continue;
        }

        // Try to match torrent name with album names
        for (final album in _albums) {
          // Check if album name is in torrent name (fuzzy match)
          if (torrentName.toLowerCase().contains(album.name.toLowerCase()) ||
              album.name.toLowerCase().contains(torrentName.toLowerCase())) {
            newProgress[album.name] = progress;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _downloadProgress = newProgress;
        });
      }
    } catch (e) {
      // Silently fail - transmission might not be ready
    }
  }

  void resetToAlbumsView() {
    if (_selectedAlbum != null) {
      setState(() {
        _selectedAlbum = null;
      });
    }
  }

  Future<void> _scanMusicFolder() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning ~/Music folder...';
      _albums = [];
    });

    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) {
        setState(() {
          _statusMessage = 'Could not find home directory';
          _isScanning = false;
        });
        appSettings.updateAlbumCount(0);
        return;
      }

      final musicDir = Directory('$homeDir/Music');
      if (!await musicDir.exists()) {
        setState(() {
          _statusMessage = 'Music folder not found';
          _isScanning = false;
        });
        appSettings.updateAlbumCount(0);
        return;
      }

      // Group songs by album folder
      final Map<String, List<Song>> albumMap = {};
      final supportedExtensions = ['.mp3', '.m4a', '.flac', '.wav', '.aac', '.ogg'];
      final artworkNames = ['folder.jpg', 'folder.png', 'cover.jpg', 'cover.png', 'artwork.jpg'];

      // Regex patterns for disc folders (case-insensitive)
      final discPatterns = [
        RegExp(r'^disc\s*\d+$', caseSensitive: false),
        RegExp(r'^cd\s*\d+$', caseSensitive: false),
        RegExp(r'^disk\s*\d+$', caseSensitive: false),
      ];

      // First, collect all file paths
      final List<Map<String, dynamic>> filesToProcess = [];
      await for (final entity in musicDir.list(recursive: true)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            var albumPath = path.dirname(entity.path);
            var folderName = path.basename(albumPath);

            // Check if this is a disc folder (Disc 1, CD 2, etc.)
            bool isDiscFolder = discPatterns.any((pattern) => pattern.hasMatch(folderName));

            // If it's a disc folder, use the parent folder as the album
            if (isDiscFolder) {
              albumPath = path.dirname(albumPath);
            }

            final albumName = path.basename(albumPath);

            // Extract artist from album folder name (format: "Artist - Album")
            String artistName = 'Unknown Artist';
            final nameParts = albumName.split(' - ');
            if (nameParts.length >= 2) {
              artistName = nameParts[0].trim();
            } else {
              // If no " - " separator, use the folder name as artist
              artistName = albumName;
            }

            filesToProcess.add({
              'path': entity.path,
              'albumPath': albumPath,
              'albumName': albumName,
              'artistName': artistName,
            });
          }
        }
      }

      // Now process files and extract metadata
      for (final fileInfo in filesToProcess) {
        final albumPath = fileInfo['albumPath'] as String;
        if (!albumMap.containsKey(albumPath)) {
          albumMap[albumPath] = [];
        }

        // Extract metadata asynchronously
        final song = await Song.fromFileWithMetadata(
          fileInfo['path'] as String,
          albumName: fileInfo['albumName'] as String,
          artistName: fileInfo['artistName'] as String,
        );

        albumMap[albumPath]!.add(song);
      }

      // Create Album objects with artwork
      final albums = <Album>[];
      for (final entry in albumMap.entries) {
        final albumPath = entry.key;
        final songs = entry.value;

        // Sort songs by track number
        songs.sort((a, b) {
          if (a.trackNumber != null && b.trackNumber != null) {
            return a.trackNumber!.compareTo(b.trackNumber!);
          }
          return a.title.compareTo(b.title);
        });

        // Look for artwork in album folder
        String? artworkPath;
        final albumDir = Directory(albumPath);

        // First try common artwork names in parent folder
        for (final artworkName in artworkNames) {
          final artFile = File(path.join(albumPath, artworkName));
          if (await artFile.exists()) {
            artworkPath = artFile.path;
            break;
          }
        }

        // If not found, check if this is a multi-disc album and look inside disc folders
        if (artworkPath == null && await albumDir.exists()) {
          // Check for disc folders
          await for (final entity in albumDir.list()) {
            if (entity is Directory) {
              final folderName = path.basename(entity.path);
              bool isDiscFolder = discPatterns.any((pattern) => pattern.hasMatch(folderName));

              if (isDiscFolder) {
                // Look for artwork inside the disc folder
                await for (final file in entity.list()) {
                  if (file is File) {
                    final ext = path.extension(file.path).toLowerCase();
                    if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
                      artworkPath = file.path;
                      break;
                    }
                  }
                }
                if (artworkPath != null) break;
              }
            }
          }
        }

        // If still not found, search for ANY image file in parent folder
        if (artworkPath == null && await albumDir.exists()) {
          await for (final entity in albumDir.list()) {
            if (entity is File) {
              final ext = path.extension(entity.path).toLowerCase();
              if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
                artworkPath = entity.path;
                break;
              }
            }
          }
        }

        // Update all songs in this album to have the artwork path
        final songsWithArtwork = songs.map((song) {
          return Song(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            filePath: song.filePath,
            duration: song.duration,
            artworkPath: artworkPath,
            trackNumber: song.trackNumber,
            bitrate: song.bitrate,
            sampleRate: song.sampleRate,
            bitDepth: song.bitDepth,
            fileSize: song.fileSize,
            format: song.format,
          );
        }).toList();

        albums.add(Album(
          id: albumPath.hashCode.toString(),
          name: path.basename(albumPath),
          path: albumPath,
          artworkPath: artworkPath,
          songs: songsWithArtwork,
        ));
      }

      setState(() {
        _albums = albums;
        _isScanning = false;
        _statusMessage = albums.isEmpty
            ? 'No music found in ~/Music'
            : 'Found ${albums.length} albums';
      });

      // Update global album count so it's visible on all screens
      appSettings.updateAlbumCount(albums.length);
    } catch (e) {
      setState(() {
        _statusMessage = 'Error scanning: $e';
        _isScanning = false;
      });
      appSettings.updateAlbumCount(0);
    }

    // Refresh top bar stats (connection quality, plays, GB downloaded)
    await _checkHealth();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedAlbum != null) {
      return _buildAlbumDetailScreen(_selectedAlbum!);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final badgeSpacing = screenWidth > 1200 ? 16.0 : 8.0; // More space when maximized

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Row(
          children: [
            Text(
              'Library',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            StatsBadges(
              onConnectionTap: _checkHealth,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (_isScanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_isScanning) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _albums.isEmpty
                ? Center(
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
                          _isScanning ? 'Scanning for music...' : 'No albums found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add music to ~/Music',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200, // Fixed maximum width (like Melo)
                      childAspectRatio: 0.75, // Width:height ratio
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _albums.length,
                    itemBuilder: (context, index) {
                      final album = _albums[index];
                      return _buildAlbumCard(album);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(Album album) {
    final isDownloading = _downloadProgress.containsKey(album.name);
    final progress = _downloadProgress[album.name] ?? 0.0;
    final showProgress = isDownloading && progress < 1.0;

    return _AlbumCardWidget(
      album: album,
      showProgress: showProgress,
      progress: progress,
      onTap: () {
        setState(() {
          _selectedAlbum = album;
        });
      },
    );
  }

  Widget _buildAlbumDetailScreen(Album album) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF000000),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _selectedAlbum = null;
                });
              },
            ),
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double expandRatio = (constraints.maxHeight - kToolbarHeight) /
                    (280 - kToolbarHeight);

                return FlexibleSpaceBar(
                  title: Text(
                    album.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: expandRatio > 0.3 ? [
                        const Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3.0,
                          color: Color.fromARGB(128, 0, 0, 0),
                        ),
                      ] : null,
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                  background: Stack(
                fit: StackFit.expand,
                children: [
                  album.artworkPath != null
                      ? Image.file(
                          File(album.artworkPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.album, size: 128),
                            );
                          },
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                        onPressed: () {
                          if (album.songs.isNotEmpty) {
                            widget.onSongTap(album.songs.first, queue: album.songs);
                          }
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          if (album.songs.isNotEmpty) {
                            // Pick random song but pass original queue - PlaybackService shuffles internally
                            final shuffled = List<Song>.from(album.songs)..shuffle();
                            widget.onSongTap(shuffled.first, queue: album.songs, isShuffled: true);
                          }
                        },
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Tracks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = album.songs[index];
                final isPlaying = widget.currentSong?.id == song.id;

                return _TrackListItem(
                  song: song,
                  isPlaying: isPlaying,
                  onTap: () => widget.onSongTap(song, queue: album.songs),
                );
              },
              childCount: album.songs.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }
}

// Separate StatefulWidget for album card with hover state
class _AlbumCardWidget extends StatefulWidget {
  final Album album;
  final bool showProgress;
  final double progress;
  final VoidCallback onTap;

  const _AlbumCardWidget({
    required this.album,
    required this.showProgress,
    required this.progress,
    required this.onTap,
  });

  @override
  State<_AlbumCardWidget> createState() => _AlbumCardWidgetState();
}

class _AlbumCardWidgetState extends State<_AlbumCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(_isHovered ? 0.4 : 0.2),
                        blurRadius: _isHovered ? 16 : 8,
                        offset: Offset(0, _isHovered ? 8 : 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Album artwork
                        widget.album.artworkPath != null
                            ? Image.file(
                                File(widget.album.artworkPath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.album, size: 64),
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(Icons.album, size: 64),
                              ),

                        // Play button overlay on hover
                        if (_isHovered && !widget.showProgress)
                          Container(
                            color: Colors.black.withOpacity(0.4),
                            child: Center(
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFA855F7),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFA855F7).withOpacity(0.4),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                        // Download progress indicator overlay
                        if (widget.showProgress)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: CircularProgressIndicator(
                                      value: widget.progress,
                                      strokeWidth: 6,
                                      backgroundColor: Colors.white.withOpacity(0.3),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${(widget.progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.album.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (widget.album.format != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.album.isLossless
                                  ? AppColors.purple.withOpacity(0.2)
                                  : AppColors.darkGray.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: widget.album.isLossless
                                    ? AppColors.purple.withOpacity(0.5)
                                    : AppColors.gray.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              widget.album.format!,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: widget.album.isLossless
                                    ? AppColors.purple
                                    : AppColors.lighterGray,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          '${widget.album.trackCount} tracks',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Hoverable track list item
class _TrackListItem extends StatefulWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;

  const _TrackListItem({
    required this.song,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_TrackListItem> createState() => _TrackListItemState();
}

class _TrackListItemState extends State<_TrackListItem> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(_TrackListItem oldWidget) {
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

  String _buildAudiophileInfo() {
    final parts = <String>[];

    print('[TRACK DISPLAY] Song: ${widget.song.title}');
    print('[TRACK DISPLAY]   format: ${widget.song.format}');
    print('[TRACK DISPLAY]   bitrate: ${widget.song.bitrate}');
    print('[TRACK DISPLAY]   sampleRate: ${widget.song.sampleRate}');
    print('[TRACK DISPLAY]   bitDepth: ${widget.song.bitDepth}');
    print('[TRACK DISPLAY]   fileSize: ${widget.song.fileSize}');

    // Format (FLAC, MP3, etc.)
    if (widget.song.format != null) {
      parts.add(widget.song.format!);
    }

    // Quality (24/192, 16/44.1, etc.)
    if (widget.song.qualityDisplay != null) {
      parts.add(widget.song.qualityDisplay!);
    }

    // Bitrate
    if (widget.song.bitrate != null) {
      parts.add('${widget.song.bitrate} kbps');
    }

    // File size
    if (widget.song.fileSizeDisplay != null) {
      parts.add(widget.song.fileSizeDisplay!);
    }

    final result = parts.isNotEmpty ? parts.join(' • ') : 'Unknown format';
    print('[TRACK DISPLAY]   Result: $result');
    return result;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
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
                        widget.song.trackNumber?.toString().padLeft(2, '0') ?? '–',
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
              fontWeight: widget.isPlaying ? FontWeight.w600 : FontWeight.w500,
              color: widget.isPlaying ? AppColors.purple : AppColors.white,
            ),
          ),
          subtitle: Text(
            _buildAudiophileInfo(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.gray,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.song.duration != null) ...[
                Text(
                  _formatDuration(widget.song.duration!),
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
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildSoundwaveBar(0.4 + (_soundwaveController.value * 0.5)),
                        const SizedBox(width: 3),
                        _buildSoundwaveBar(0.9 - (_soundwaveController.value * 0.6)),
                        const SizedBox(width: 3),
                        _buildSoundwaveBar(0.5 + (_soundwaveController.value * 0.4)),
                      ],
                    );
                  },
                ),
            ],
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

