import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:media_kit/media_kit.dart';
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
import 'screens/library_screen.dart';

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

// Simple service for managing favorites and ratings
class FavoritesService extends ChangeNotifier {
  final Map<String, bool> _favorites = {};
  final Map<String, int> _ratings = {};

  bool isFavorite(String songPath) => _favorites[songPath] ?? false;
  int getRating(String songPath) => _ratings[songPath] ?? 0;

  void toggleFavorite(String songPath) {
    _favorites[songPath] = !(_favorites[songPath] ?? false);
    notifyListeners();
  }

  void setRating(String songPath, int rating) {
    _ratings[songPath] = rating;
    notifyListeners();
  }
}

// Global instances
final appSettings = AppSettings();
final daemonManager = DaemonManager();
final favoritesService = FavoritesService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit with error handling (may fail on some Windows systems)
  try {
    MediaKit.ensureInitialized();
    print('[STARTUP] ✅ MediaKit initialized');
  } catch (e, stackTrace) {
    print('[STARTUP] ⚠️  MediaKit initialization failed: $e');
    print('[STARTUP] Audio playback may not work');
    print('[STARTUP] Stack trace: $stackTrace');
  }

  print('═══════════════════════════════════════════════');
  print('🎵 TrustTune Starting Up');
  print('═══════════════════════════════════════════════');

  // Load settings
  print('[STARTUP] Loading settings...');
  await appSettings.load();
  print('[STARTUP] Settings loaded');

  print('[STARTUP] ═══════════════════════════════════════════════');
  print('[STARTUP] Launching app UI...');
  runApp(const KarmaPlayerApp());

  // Start transmission daemon in background (non-blocking)
  print('[STARTUP] ═══════════════════════════════════════════════');
  print('[STARTUP] Starting transmission daemon in background...');
  print('[STARTUP] ═══════════════════════════════════════════════');

  Future.microtask(() async {
    try {
      final started = await daemonManager.startDaemon(customDownloadDir: appSettings.customDownloadDir);
      if (started) {
        print('[STARTUP] ✅ Transmission daemon started successfully');
      } else {
        print('[STARTUP] ❌ Failed to start transmission daemon');
      }
    } catch (e, stackTrace) {
      print('[STARTUP] ❌ ERROR starting daemon: $e');
      print('[STARTUP] Stack trace: $stackTrace');
    }
  });
}

class KarmaPlayerApp extends StatelessWidget {
  const KarmaPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karma Player',
      restorationScopeId: 'app',
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
  final GlobalKey<LibraryScreenState> _libraryKey = GlobalKey<LibraryScreenState>();

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

    // Global keyboard handler for Space key
    ServicesBinding.instance.keyboard.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Only handle Space key press when a song is loaded
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      // Don't intercept Space key if user is typing in a text field
      final focusNode = FocusManager.instance.primaryFocus;

      if (focusNode != null && focusNode.context != null) {
        // Check if there's an EditableText widget in the focus tree
        final editableText = focusNode.context!.findAncestorWidgetOfExactType<EditableText>();

        if (editableText != null) {
          // We're in a text field - let it handle the space
          return false;
        }
      }

      // Handle play/pause only if a song is loaded and no text field has focus
      if (_playbackService.currentSong != null) {
        _playbackService.togglePlayPause();
        return true; // Consume the event
      }
    }
    return false; // Let other events through
  }

  @override
  void dispose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Remove keyboard handler
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyEvent);

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
      _playbackService.player?.pause();
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
