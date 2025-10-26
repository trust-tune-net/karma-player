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

enum RepeatMode { off, all, one }

// Reusable stats badges widget for AppBar
// Uses ListenableBuilder to rebuild when appSettings changes (ChangeNotifier)
class StatsBadges extends StatelessWidget {
  final int? albumsCount; // Optional - only shown in Library screen
  final VoidCallback? onConnectionTap; // Callback for connection badge tap

  const StatsBadges({
    super.key,
    this.albumsCount,
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

        // Albums count badge (only if provided)
        if (albumsCount != null) ...[
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
                  '$albumsCount',
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],

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
  final Player _player = Player();
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Queue management
  List<Song> _queue = [];
  List<Song> _originalQueue = []; // Store original order for unshuffle
  int _currentIndex = 0;
  bool _isShuffled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  double _volume = 0.5; // 0.0 to 1.0

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

    _player.stream.playing.listen((playing) {
      setState(() {
        _isPlaying = playing;
      });

      // Control animation based on playing state
      if (playing) {
        _soundwaveController.repeat(reverse: true);
      } else {
        _soundwaveController.stop();
      }
    });
    _player.stream.position.listen((position) {
      setState(() {
        _position = position;
      });
    });
    _player.stream.duration.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    // Auto-play next track when current finishes
    _player.stream.completed.listen((completed) {
      if (completed) {
        _playNext();
      }
    });

    // Set initial volume
    _player.setVolume(_volume * 100);
  }

  @override
  void dispose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    _soundwaveController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Stop player when app is being terminated or going to background
    // This ensures MPV shuts down cleanly before the app process is killed
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      _player.pause();
    }
  }

  void _playSong(Song song, {List<Song>? queue, bool? isShuffled}) {
    setState(() {
      _currentSong = song;
      if (queue != null) {
        // Always save the original unshuffled queue
        _originalQueue = List<Song>.from(queue);

        // If shuffle requested, shuffle the queue
        if (isShuffled == true) {
          final shuffled = List<Song>.from(queue)..shuffle();
          // Keep the selected song at the start
          shuffled.remove(song);
          shuffled.insert(0, song);
          _queue = shuffled;
          _currentIndex = 0;
          _isShuffled = true;
        } else {
          _queue = queue;
          _currentIndex = queue.indexOf(song);
          _isShuffled = false;
        }
      } else {
        _queue = [song];
        _currentIndex = 0;
        _originalQueue = [song];
      }
    });
    _player.open(Media(song.filePath));
    _player.play();
    // Track play count
    appSettings.incrementPlays();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _playNext() {
    if (_queue.isEmpty) return;

    // Handle repeat one - replay current song
    if (_repeatMode == RepeatMode.one && _currentSong != null) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }

    int nextIndex = _currentIndex + 1;

    // Handle end of queue
    if (nextIndex >= _queue.length) {
      if (_repeatMode == RepeatMode.all) {
        nextIndex = 0; // Loop back to start
      } else {
        return; // Stop at end
      }
    }

    // Don't pass queue parameter - we're moving within existing queue
    // Passing queue would overwrite _originalQueue with shuffled queue
    setState(() {
      _currentIndex = nextIndex;
      _currentSong = _queue[nextIndex];
    });
    _player.open(Media(_queue[nextIndex].filePath));
    _player.play();
    appSettings.incrementPlays();
  }

  void _playPrevious() {
    if (_queue.isEmpty) return;

    final prevIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    if (prevIndex >= 0) {
      // Don't pass queue parameter - we're moving within existing queue
      setState(() {
        _currentIndex = prevIndex;
        _currentSong = _queue[prevIndex];
      });
      _player.open(Media(_queue[prevIndex].filePath));
      _player.play();
      appSettings.incrementPlays();
    }
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffled = !_isShuffled;
      if (_isShuffled) {
        // Store original queue if not already stored
        if (_originalQueue.isEmpty || _originalQueue.length != _queue.length) {
          _originalQueue = List<Song>.from(_queue);
        }
        // Shuffle the queue
        final currentSong = _currentSong;
        final shuffled = List<Song>.from(_queue)..shuffle();
        // Keep current song at current position
        if (currentSong != null) {
          shuffled.remove(currentSong);
          shuffled.insert(_currentIndex, currentSong);
        }
        _queue = shuffled;
      } else {
        // Restore original order
        if (_originalQueue.isNotEmpty && _currentSong != null) {
          _queue = List<Song>.from(_originalQueue);
          _currentIndex = _queue.indexOf(_currentSong!);
        }
      }
    });
  }

  void _toggleRepeat() {
    setState(() {
      switch (_repeatMode) {
        case RepeatMode.off:
          _repeatMode = RepeatMode.all;
          break;
        case RepeatMode.all:
          _repeatMode = RepeatMode.one;
          break;
        case RepeatMode.one:
          _repeatMode = RepeatMode.off;
          break;
      }
    });
  }

  void _setVolume(double volume) {
    setState(() {
      _volume = volume.clamp(0.0, 1.0);
    });
    _player.setVolume(_volume * 100);
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

                      const Spacer(),

                      // Settings at very bottom
                      _buildNavItem(
                        icon: Icons.settings_outlined,
                        selectedIcon: Icons.settings,
                        label: 'Settings',
                        index: 3,
                      ),

                      const SizedBox(height: 16), // Minimal space for player bar
                    ],
                  ),
                ),

                // Main content area
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      LibraryScreen(key: _libraryKey, onSongTap: _playSong, currentSong: _currentSong),
                      const SearchScreen(),
                      const DownloadsScreen(),
                      const SettingsScreen(),
                    ],
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
    if (_currentSong == null) return const SizedBox.shrink();

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
              value: _duration.inMilliseconds > 0
                  ? _position.inMilliseconds / _duration.inMilliseconds
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
                          child: _currentSong!.artworkPath != null
                              ? Image.file(
                                  File(_currentSong!.artworkPath!),
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
                              _currentSong!.title,
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
                              _currentSong!.artist,
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
                            color: _queue.length > 1
                                ? const Color(0xFFAAAAAA)
                                : const Color(0xFF444444),
                            onPressed: _queue.length > 1 ? _playPrevious : null,
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _togglePlayPause,
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
                                  return _isPlaying
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
                            color: _queue.length > 1
                                ? const Color(0xFFAAAAAA)
                                : const Color(0xFF444444),
                            onPressed: _queue.length > 1 ? _playNext : null,
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Time display
                      Text(
                        '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
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
                          color: _isShuffled ? AppColors.purple : const Color(0xFFAAAAAA),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onPressed: _queue.length > 1 ? _toggleShuffle : null,
                        ),

                        // Repeat button
                        IconButton(
                          icon: Icon(
                            _repeatMode == RepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                          ),
                          iconSize: 20,
                          color: _repeatMode != RepeatMode.off
                              ? AppColors.purple
                              : const Color(0xFFAAAAAA),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onPressed: _queue.length > 0 ? _toggleRepeat : null,
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
                                _volume == 0
                                    ? Icons.volume_off_outlined
                                    : _volume < 0.5
                                        ? Icons.volume_down_outlined
                                        : Icons.volume_up_outlined,
                              ),
                              iconSize: 20,
                              color: const Color(0xFFAAAAAA),
                              onPressed: () {
                                // Toggle mute
                                _setVolume(_volume == 0 ? 0.5 : 0);
                              },
                            ),
                            SizedBox(
                              width: volumeSliderWidth,
                              child: Slider(
                                value: _volume,
                                onChanged: _setVolume,
                                activeColor: AppColors.purple,
                                inactiveColor: const Color(0xFF3A3A3E),
                              ),
                            ),
                            if (showVolumePercentage) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${(_volume * 100).round()}%',
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
        return;
      }

      final musicDir = Directory('$homeDir/Music');
      if (!await musicDir.exists()) {
        setState(() {
          _statusMessage = 'Music folder not found';
          _isScanning = false;
        });
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
    } catch (e) {
      setState(() {
        _statusMessage = 'Error scanning: $e';
        _isScanning = false;
      });
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
              albumsCount: _albums.length,
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
                            // Shuffle the queue first, then play first song of shuffled queue
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

// SEARCH SCREEN (preserved from original)
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  WebSocketChannel? _channel;

  String _statusMessage = 'Enter a search query';
  int _progress = 0;
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  void _search() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _progress = 0;
      _statusMessage = 'Searching...';
      _results = [];
    });

    try {
      // Make HTTP POST request to search API
      final response = await http.post(
        Uri.parse('${appSettings.searchApiUrl}/api/search'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': _searchController.text,
          'format_filter': null,
          'min_seeders': 1,
          'limit': 50,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _results = List<Map<String, dynamic>>.from(data['results'] ?? []);
          _statusMessage = 'Found ${_results.length} results';
          _isSearching = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Search failed: ${response.statusCode}';
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Search error: $e';
        _isSearching = false;
      });
    }
  }

  void _showTransmissionHelp() {
    // Detect platform and build appropriate instructions
    String platformTitle;
    List<Widget> platformInstructions;

    if (Platform.isLinux) {
      platformTitle = 'Quick Setup (Linux):';
      platformInstructions = [
        const Text('1. Install Transmission:'),
        const SizedBox(height: 4),
        const SelectableText(
          '   sudo apt install transmission-daemon',
          style: TextStyle(fontFamily: 'Courier', backgroundColor: Color(0xFFF5F5F5)),
        ),
        const SizedBox(height: 4),
        const Text('   Or for Fedora:', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        const SelectableText(
          '   sudo dnf install transmission-daemon',
          style: TextStyle(fontFamily: 'Courier', backgroundColor: Color(0xFFF5F5F5)),
        ),
        const SizedBox(height: 12),
        const Text('2. Start Transmission daemon:'),
        const SizedBox(height: 4),
        const SelectableText(
          '   sudo systemctl start transmission-daemon',
          style: TextStyle(fontFamily: 'Courier', backgroundColor: Color(0xFFF5F5F5)),
        ),
      ];
    } else if (Platform.isWindows) {
      platformTitle = 'Quick Setup (Windows):';
      platformInstructions = [
        const Text('1. Download Transmission from:'),
        const SizedBox(height: 4),
        const SelectableText(
          '   https://transmissionbt.com/download',
          style: TextStyle(fontSize: 13, color: Colors.blue),
        ),
        const SizedBox(height: 12),
        const Text('2. Install and run Transmission'),
        const SizedBox(height: 4),
        const Text('   Keep it running in the background', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        const Text('3. (Optional) Auto-start with Windows:'),
        const SizedBox(height: 4),
        const Text('   Right-click system tray icon → "Start when Windows starts"', style: TextStyle(fontSize: 12)),
      ];
    } else {
      // macOS
      platformTitle = 'Quick Setup (macOS):';
      platformInstructions = [
        const Text('1. Install Transmission:'),
        const SizedBox(height: 4),
        const SelectableText(
          '   brew install transmission',
          style: TextStyle(fontFamily: 'Courier', backgroundColor: Color(0xFFF5F5F5)),
        ),
        const SizedBox(height: 12),
        const Text('2. Start Transmission daemon:'),
        const SizedBox(height: 4),
        const SelectableText(
          '   transmission-daemon',
          style: TextStyle(fontFamily: 'Courier', backgroundColor: Color(0xFFF5F5F5)),
        ),
        const SizedBox(height: 12),
        const Text('Or download the GUI app from:', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        const SelectableText(
          '   https://transmissionbt.com/download',
          style: TextStyle(fontSize: 13, color: Colors.blue),
        ),
      ];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Transmission Not Running'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TrustTune needs Transmission to download torrents.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Text(
                platformTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...platformInstructions,
              const SizedBox(height: 16),
              const Text(
                'See full setup guide at: github.com/trust-tune-net/karma-player',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  void _startDownload(Map<String, dynamic> torrent) async {
    final magnetLink = torrent['magnet_link'];
    final title = torrent['title'];

    // Validate magnet link exists and is properly formatted
    if (magnetLink == null || magnetLink.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No magnet link available for this torrent'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate it starts with magnet:
    if (!magnetLink.toString().startsWith('magnet:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid magnet link format: ${magnetLink.toString().substring(0, 20)}...'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      print('Invalid magnet link: $magnetLink');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting download: $title')),
    );

    try {
      final transmissionClient = TransmissionClient(baseUrl: appSettings.transmissionRpcUrl);

      // Add torrent to transmission
      final torrentId = await transmissionClient.addTorrent(magnetLink: magnetLink);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download started: $title'),
          backgroundColor: Colors.green,
        ),
      );
      print('Torrent ID: $torrentId');
    } catch (e) {
      // Check if it's a connection error (Transmission not running)
      final errorStr = e.toString();
      final isConnectionError = errorStr.contains('Connection refused') ||
                                 errorStr.contains('Failed to connect') ||
                                 errorStr.contains('SocketException');

      if (isConnectionError) {
        // Transmission daemon is not running
        _showTransmissionHelp();
      } else {
        // Other error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting download: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('Download error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Row(
          children: [
            Text(
              'Discover Music',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const StatsBadges(), // No albums count for Search screen
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search for music',
                hintText: 'e.g., radiohead ok computer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              enabled: !_isSearching,
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),

            // Search Button
            FilledButton.icon(
              onPressed: _isSearching ? null : _search,
              icon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('Search'),
            ),
            const SizedBox(height: 24),

            // Status and Progress
            if (_isSearching) ...[
              LinearProgressIndicator(value: _progress / 100),
              const SizedBox(height: 8),
            ],
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Results List
            if (_results.isNotEmpty) ...[
              Text(
                'Found ${_results.length} results:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  final torrent = result['torrent'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: result['rank'] == 1
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Text(
                          '${result['rank']}',
                          style: TextStyle(
                            color: result['rank'] == 1
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: result['rank'] == 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      title: Text(
                        torrent['title'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(result['explanation']),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (torrent['format'] != null)
                                Chip(
                                  label: Text(torrent['format']),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              Chip(
                                label: Text('${torrent['seeders']} seeders'),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              Chip(
                                label: Text(torrent['size_formatted']),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _startDownload(torrent),
                        tooltip: 'Download',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// DOWNLOADS SCREEN
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _downloads = [];
  bool _isLoading = true;
  Timer? _pollTimer;
  late final TransmissionClient _transmissionClient;

  // Format bytes per second to human-readable speed
  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    if (bytesPerSecond > 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSecond > 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '$bytesPerSecond B/s';
  }

  // Format ETA seconds to human-readable time
  String _formatETA(int seconds) {
    if (seconds < 0) return 'Unknown';
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }

  // Get human-friendly status text
  String _getStatusText(String status) {
    switch (status) {
      case 'download':
        return 'Downloading';
      case 'seed':
        return 'Seeding';
      case 'check':
        return 'Verifying';
      case 'stopped':
        return 'Stopped';
      default:
        return status;
    }
  }

  @override
  void initState() {
    super.initState();
    _transmissionClient = TransmissionClient(baseUrl: appSettings.transmissionRpcUrl);
    _loadDownloads();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadDownloads());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    try {
      print('[Downloads] Fetching torrents from transmission...');
      final torrents = await _transmissionClient.getTorrents();
      print('[Downloads] Got ${torrents.length} torrents from transmission');

      for (var t in torrents) {
        print('[Downloads]   - [${t.id}] ${t.name} (${(t.percentDone * 100).toStringAsFixed(1)}%)');
      }

      if (mounted) {
        setState(() {
          // Filter: only show active downloads (not completed/stopped)
          final activeTorrents = torrents.where((t) =>
            t.percentDone < 1.0 || t.status != 'stopped'
          ).toList();

          // Convert torrents to the same format expected by UI
          _downloads = activeTorrents.map((t) => {
            'id': t.id.toString(),
            'title': t.name,
            'progress': t.percentDone,  // Already 0.0-1.0
            'status': t.status,
            'download_speed': t.rateDownload,
            'upload_speed': t.rateUpload,
            'eta': t.eta,
          }).toList();
          _isLoading = false;
          print('[Downloads] Updated UI with ${_downloads.length} active downloads (${torrents.length} total)');
        });
      } else {
        print('[Downloads] Widget not mounted, skipping setState');
      }
    } catch (e) {
      print('[Downloads] Error loading downloads: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteDownload(String downloadId, String title) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "$title"?\n\nThis will remove the download but keep any completed files.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Delete via transmission
    try {
      final torrentId = int.parse(downloadId);
      await _transmissionClient.removeTorrents(ids: [torrentId], deleteData: false);

      // Refresh the list
      _loadDownloads();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "$title"')),
        );
      }
    } catch (e) {
      print('Error deleting download: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting download')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Row(
          children: [
            Text(
              'Downloads',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const StatsBadges(), // No albums count for Downloads screen
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No downloads yet',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start downloading music from the Search tab',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _downloads.length,
                  itemBuilder: (context, index) {
                    final download = _downloads[index];
                    final progress = (download['progress'] ?? 0.0) as double;
                    final status = download['status'] ?? 'unknown';
                    final title = download['title'] ?? 'Unknown';
                    final downloadId = download['id'] ?? '';
                    final downloadSpeed = download['download_speed'] as int? ?? 0;
                    final uploadSpeed = download['upload_speed'] as int? ?? 0;
                    final eta = download['eta'] as int? ?? -1;

                    // Build status line with speed and ETA
                    String statusLine = '${(progress * 100).toStringAsFixed(1)}%';
                    if (status == 'download' && downloadSpeed > 0) {
                      statusLine += ' • ↓ ${_formatSpeed(downloadSpeed)}';
                      if (uploadSpeed > 0) {
                        statusLine += ' • ↑ ${_formatSpeed(uploadSpeed)}';
                      }
                      if (eta > 0) {
                        statusLine += ' • ${_formatETA(eta)}';
                      }
                    } else if (status == 'seed') {
                      statusLine += ' • Seeding';
                      if (uploadSpeed > 0) {
                        statusLine += ' • ↑ ${_formatSpeed(uploadSpeed)}';
                      }
                    } else {
                      statusLine += ' • ${_getStatusText(status)}';
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: status == 'download'
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          status == 'download'
                              ? Icons.downloading
                              : status == 'seed'
                                  ? Icons.upload
                                  : status == 'check'
                                      ? Icons.check_circle_outline
                                      : Icons.download,
                          color: status == 'download'
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusLine,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteDownload(downloadId, title),
                        tooltip: 'Remove',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
    );
  }
}

// NOW PLAYING SCREEN
class NowPlayingScreen extends StatelessWidget {
  final Song? song;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final Duration position;
  final Duration duration;

  const NowPlayingScreen({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.onPlayPause,
    required this.position,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
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
        automaticallyImplyLeading: false, // Remove back button - we're in a tab view!
      ),
      body: SafeArea(
        child: SingleChildScrollView( // FIX: Make scrollable to prevent overflow
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
              const SizedBox(height: 20),

              // Album artwork - Flexible size
              Container(
                width: 280, // Smaller to fit better
                height: 280,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.album,
                size: 160,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 40),

            // Song info with better typography
            Text(
              song!.title,
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
              song!.artist,
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFFA855F7), // Purple like references
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
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
                      overlayColor: Color(0xFFA855F7).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: duration.inMilliseconds > 0
                          ? position.inMilliseconds / duration.inMilliseconds
                          : 0.0,
                      onChanged: null, // Read-only for now
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
                  onPressed: () {
                    // TODO: Previous track
                  },
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFA855F7),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    iconSize: 40,
                    color: Colors.white,
                    onPressed: onPlayPause,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: 40,
                  color: const Color(0xFFCCCCCC),
                  onPressed: () {
                    // TODO: Next track
                  },
                ),
              ],
            ),
            const SizedBox(height: 40), // Bottom padding for scrolling
            ],
            ),
          ),
        ),
      ),
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

// SETTINGS SCREEN
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _downloadDir = '';
  String _configDir = '';
  bool _daemonRunning = false;
  bool _isCheckingDaemon = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkDaemonStatus();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _downloadDir = daemonManager.getDownloadDir(appSettings.customDownloadDir);
      _configDir = daemonManager.configDir;
    });
  }

  Future<void> _checkDaemonStatus() async {
    setState(() {
      _isCheckingDaemon = true;
    });

    final isRunning = await daemonManager.isDaemonRunning();

    setState(() {
      _daemonRunning = isRunning;
      _isCheckingDaemon = false;
    });
  }

  Future<void> _restartDaemon() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restarting daemon...')),
    );

    await daemonManager.stopDaemon();
    await Future.delayed(const Duration(seconds: 1));
    final started = await daemonManager.startDaemon(customDownloadDir: appSettings.customDownloadDir);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(started ? 'Daemon restarted successfully' : 'Failed to restart daemon'),
          backgroundColor: started ? Colors.green : Colors.red,
        ),
      );
      _checkDaemonStatus();
      _loadSettings(); // Reload to show updated directory
    }
  }

  Future<void> _editSearchApiUrl() async {
    final controller = TextEditingController(text: appSettings.searchApiUrl);
    final newUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Search API URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Search API URL',
            hintText: 'https://example.com',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newUrl != null && newUrl.isNotEmpty && newUrl != appSettings.searchApiUrl) {
      await appSettings.saveSearchApiUrl(newUrl);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search API URL updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _openDiagnostics() async {
    await showDialog(
      context: context,
      builder: (context) => DiagnosticsDialog(
        daemonManager: daemonManager,
        appSettings: appSettings,
      ),
    );
  }

  Future<void> _editDownloadDir() async {
    final controller = TextEditingController(text: _downloadDir);
    final newDir = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Download Directory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Download Directory',
            hintText: '/Users/username/Downloads',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newDir != null && newDir.isNotEmpty && newDir != _downloadDir) {
      await appSettings.saveDownloadDir(newDir);
      setState(() {
        _downloadDir = newDir;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Download directory updated. Restart daemon to apply changes.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Restart',
              onPressed: _restartDaemon,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Row(
          children: [
            Text(
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const StatsBadges(), // No albums count for Settings screen
          ],
        ),
      ),
      body: ListView(
        children: [
          // Diagnostics Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(
              onPressed: _openDiagnostics,
              icon: const Icon(Icons.bug_report),
              label: const Text('Run System Diagnostics'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const Divider(),

          // Daemon Settings Section
          ListTile(
            title: Text(
              'Transmission Daemon',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: Icon(
              _daemonRunning ? Icons.check_circle : Icons.error,
              color: _daemonRunning ? Colors.green : Colors.red,
            ),
            title: const Text('Daemon Status'),
            subtitle: Text(
              _isCheckingDaemon
                  ? 'Checking...'
                  : _daemonRunning
                      ? 'Running'
                      : 'Not running',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _checkDaemonStatus,
                  tooltip: 'Check status',
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt),
                  onPressed: _restartDaemon,
                  tooltip: 'Restart daemon',
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Daemon Port'),
            subtitle: const Text('9091'),
          ),
          ListTile(
            leading: const Icon(Icons.settings_applications),
            title: const Text('Config Directory'),
            subtitle: Text(
              _configDir.isNotEmpty ? _configDir : 'Loading...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          const Divider(),

          // Download Settings Section
          ListTile(
            title: Text(
              'Downloads',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Download Directory'),
            subtitle: Text(
              _downloadDir.isNotEmpty ? _downloadDir : 'Loading...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editDownloadDir,
              tooltip: 'Change download directory',
            ),
          ),
          const Divider(),

          // API Settings Section
          ListTile(
            title: Text(
              'API Configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.search,
              color: appSettings.isUsingDefaultApi
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
            ),
            title: Row(
              children: [
                const Text('Search API URL'),
                const SizedBox(width: 8),
                if (!appSettings.isUsingDefaultApi)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'CUSTOM',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              appSettings.displaySearchApiUrl,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editSearchApiUrl,
              tooltip: 'Change search API URL',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Transmission RPC URL'),
            subtitle: Text(
              appSettings.transmissionRpcUrl,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          const Divider(),

          // About Section
          ListTile(
            title: Text(
              'About',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.music_note, color: Color(0xFFA855F7)),
            title: const Text('Trust Tune Network'),
            subtitle: Text(
              'Phase 0 of the Trust Tune Network\n\nA fair music ecosystem where artists get 95% of revenue and listeners get high-quality, DRM-free music. Built on transparency, community validation, and decentralized infrastructure.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const ListTile(
            leading: Icon(Icons.search, color: Color(0xFFA855F7)),
            title: Text('What'),
            subtitle: Text('AI-powered music discovery that finds the highest quality audio (FLAC, hi-res) from multiple sources, ranked and explained by AI.'),
          ),
          const ListTile(
            leading: Icon(Icons.favorite, color: Color(0xFFA855F7)),
            title: Text('Why'),
            subtitle: Text('Spotify pays \$0.003/stream (30% to artists). We\'re building a protocol where artists get 95% + transparent analytics showing WHO listens and WHERE.'),
          ),
          const ListTile(
            leading: Icon(Icons.lightbulb_outline, color: Color(0xFFA855F7)),
            title: Text('How'),
            subtitle: Text('Search → MusicBrainz canonical metadata → Multi-source torrent search (Jackett/1337x) → AI quality ranking → Transmission downloads → Local library. Future: Community validation + creator payments.'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline, color: Color(0xFFA855F7)),
            title: Text('Status'),
            subtitle: Text('Phase 0 (Beta): Desktop player with AI search works today. Phase 1-2: Federation & web app. Phase 3-5: Creator compensation + community validation.'),
          ),
          ListTile(
            leading: const Icon(Icons.code, color: Color(0xFFA855F7)),
            title: const Text('Version'),
            subtitle: const Text('v0.3.1-beta'),
          ),
          if (kDebugMode)
            ListTile(
              leading: Icon(
                Icons.bug_report,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Debug Mode'),
              subtitle: const Text('Running in development mode'),
            ),
        ],
      ),
    );
  }
}
