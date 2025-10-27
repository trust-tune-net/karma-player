# 🎨 TrustTune GUI Architecture Analysis

## Overview

The GUI is a **Flutter desktop application** (947 lines in main.dart) with a **hybrid architecture**:
- **Mostly monolithic** - Much UI logic in single file
- **Some modularity** - Separate screens and services
- **No formal state management** - Uses ChangeNotifier pattern
- **Direct HTTP/WebSocket** - No repository layer

## Metrics

```
Total Dart Files: 16
Total Lines: ~5,300

main.dart:           947 lines  (18% of codebase)
screens/:          2,875 lines  (54%)
services/:         1,139 lines  (21%)
models/:             375 lines  (7%)
widgets/:            ~100 lines (minor)
```

## File Structure

```
lib/
├── main.dart                    [947 lines] App entry + routing + theme
├── models/                      [375 lines total]
│   ├── song.dart               [232 lines] Song metadata + file info
│   ├── album.dart              [62 lines]  Album grouping
│   └── torrent.dart            [81 lines]  Torrent result model
├── services/                    [1,139 lines total]
│   ├── daemon_manager.dart     [187 lines] Transmission lifecycle
│   ├── transmission_client.dart[169 lines] RPC communication
│   ├── playback_service.dart   [278 lines] Media player control
│   ├── app_settings.dart       [145 lines] User preferences
│   └── diagnostics_service.dart[360 lines] Health checks
├── screens/                     [2,875 lines total]
│   ├── search_screen.dart      [421 lines] Query input + results
│   ├── library_screen.dart     [1,059 lines] 🔴 LARGEST - Music collection
│   ├── now_playing_screen.dart [686 lines] Player controls
│   ├── downloads_screen.dart   [299 lines] Torrent progress
│   └── settings_screen.dart    [410 lines] Configuration
└── widgets/                     [~100 lines total]
    ├── status_bar.dart         [~60 lines] Connection indicator
    └── diagnostics_dialog.dart [~40 lines] Debug info modal
```

---

## Key Components Breakdown

### 1. main.dart [947 lines] - App Core

**Purpose:** Application entry point, routing, theme, and some business logic

**Structure:**
```dart
void main() async {
  // Initialize media player
  MediaKit.ensureInitialized();
  runApp(TrustTuneApp());
}

class TrustTuneApp {
  // Material app with dark theme
  // Bottom navigation: Search | Library | Downloads | Settings
}

// Global singletons (❌ Anti-pattern)
final appSettings = AppSettings();
final daemonManager = DaemonManager();
final favoritesService = FavoritesService();
```

**Issues:**
- 🔴 **Too large** - Should be split into smaller files
- 🔴 **Global singletons** - Violates dependency injection
- 🔴 **Mixed concerns** - Routing + theme + state in one file

**Refactor Priority:** ⭐⭐⭐⭐⭐ (High)

---

### 2. SearchScreen [421 lines]

**Purpose:** Search for music torrents

**Architecture:**
```dart
class _SearchScreenState {
  TextEditingController _searchController;
  WebSocketChannel? _channel;  // WebSocket for real-time updates

  String _statusMessage = 'Enter a search query';
  int _progress = 0;
  List<Map<String, dynamic>> _results = [];  // ❌ Untyped
  bool _isSearching = false;

  void _search() async {
    // POST to search API
    final response = await http.post(
      Uri.parse('${appSettings.searchApiUrl}/api/search'),
      body: json.encode({...})
    );

    // Parse and display results
    setState(() {
      _results = List<Map<String, dynamic>>.from(data['results']);
    });
  }
}
```

**Data Flow:**
1. User enters query → `_searchController`
2. HTTP POST → Search API (Python FastAPI)
3. Response → Parse JSON
4. Update state → Rebuild UI

**Issues:**
- ⚠️ **Untyped results** - Should use `TorrentResult` model
- ⚠️ **No error recovery** - Needs retry logic
- ⚠️ **Direct HTTP** - No repository layer

**Refactor Priority:** ⭐⭐⭐ (Medium)

---

### 3. LibraryScreen [1,059 lines] 🔴 **LARGEST FILE**

**Purpose:** Display user's music collection

**Structure:**
```dart
class _LibraryScreenState {
  List<Song> _songs = [];
  List<Album> _albums = [];
  String _view = 'songs';  // 'songs' | 'albums'
  String _sortBy = 'title';

  @override
  void initState() {
    _loadLibrary();  // Scan ~/Music directory
  }

  Future<void> _loadLibrary() async {
    // Recursively scan music folder for audio files
    final musicDir = Directory(appSettings.musicFolderPath);
    final files = musicDir.listSync(recursive: true);

    // Parse metadata (ID3 tags)
    for (final file in files) {
      final song = await _parseMusicFile(file);
      _songs.add(song);
    }

    // Group into albums
    _albums = _groupByAlbum(_songs);
  }
}
```

**Features:**
- ✅ Sorts: Title, Artist, Album, Date Added
- ✅ Views: Songs list, Albums grid
- ✅ Search: Filter by title/artist
- ✅ Context menu: Play, Add to queue, Show file info
- ✅ Favorites & Ratings integration

**Issues:**
- 🔴 **1,059 lines** - Should be split into:
  - `LibraryScreen` (container)
  - `SongListView` widget
  - `AlbumGridView` widget
  - `LibraryService` (scanning logic)
- 🔴 **Synchronous file scanning** - Blocks UI on large libraries
- ⚠️ **No caching** - Re-scans on every app launch
- ⚠️ **No database** - Everything in memory

**Refactor Priority:** ⭐⭐⭐⭐⭐ (Critical)

**Suggested Split:**
```dart
// lib/screens/library/
library_screen.dart       [200 lines] - Container + state
song_list_view.dart       [300 lines] - Songs table
album_grid_view.dart      [300 lines] - Albums grid
library_service.dart      [200 lines] - File scanning
library_database.dart     [100 lines] - SQLite caching
```

---

### 4. NowPlayingScreen [686 lines]

**Purpose:** Music player controls

**Architecture:**
```dart
class _NowPlayingScreenState {
  PlaybackService playback = PlaybackService();

  Widget build() {
    return Stack([
      // Background: Album art with blur
      BlurredAlbumArt(),

      // Center: Large album art
      AlbumArtCard(),

      // Bottom: Player controls
      PlaybackControls(
        onPlay: () => playback.play(),
        onPause: () => playback.pause(),
        onNext: () => playback.next(),
        onPrevious: () => playback.previous(),
      ),

      // Seek bar
      ProgressSlider(),

      // Volume control
      VolumeSlider(),
    ]);
  }
}
```

**Features:**
- ✅ Album art display (from file metadata)
- ✅ Play/pause/next/previous
- ✅ Seek bar with time labels
- ✅ Volume control
- ✅ Favorites & ratings
- ✅ File info panel (codec, bitrate, sample rate)
- ✅ Shuffle & repeat modes

**Issues:**
- ⚠️ **Large file** - Could extract widgets
- ⚠️ **Tight coupling** - Direct access to `PlaybackService`

**Refactor Priority:** ⭐⭐ (Low - works well)

---

### 5. DownloadsScreen [299 lines]

**Purpose:** Monitor torrent downloads

**Architecture:**
```dart
class _DownloadsScreenState {
  Timer? _refreshTimer;
  List<Torrent> _torrents = [];

  @override
  void initState() {
    _loadTorrents();
    _refreshTimer = Timer.periodic(Duration(seconds: 1), (_) {
      _loadTorrents();  // Poll transmission RPC every second
    });
  }

  Future<void> _loadTorrents() async {
    final client = TransmissionClient();
    final torrents = await client.getTorrents();
    setState(() => _torrents = torrents);
  }
}
```

**Features:**
- ✅ Real-time progress (1s polling)
- ✅ Download speed/ETA
- ✅ Pause/resume/remove actions
- ✅ Seeding status

**Issues:**
- ⚠️ **Polling** - Should use WebSocket for real-time updates
- ⚠️ **No error handling** - If Transmission crashes, UI breaks

**Refactor Priority:** ⭐⭐ (Low)

---

### 6. SettingsScreen [410 lines]

**Purpose:** App configuration

**Settings:**
```dart
class AppSettings extends ChangeNotifier {
  String musicFolderPath = '~/Music';
  String searchApiUrl = 'http://localhost:3000';
  String transmissionUrl = 'http://localhost:9091';
  bool darkMode = true;
  double volume = 1.0;

  // Persisted with SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('musicFolderPath', musicFolderPath);
    // ...
  }
}
```

**Features:**
- ✅ Music folder picker
- ✅ Search API URL
- ✅ Transmission URL
- ✅ Diagnostics (connection tests)
- ✅ About section (version info)

**Issues:**
- ✅ **Well-structured** - No major issues

**Refactor Priority:** ⭐ (None)

---

## Services Layer

### 1. DaemonManager [187 lines] ✅

**Purpose:** Manage transmission-daemon lifecycle

```dart
class DaemonManager {
  Process? _daemonProcess;
  bool _isRunning = false;

  String get daemonPath {
    // Check bundled binary first
    if (File(bundledPath).existsSync()) return bundledPath;

    // Fallback to system transmission
    if (File('/opt/homebrew/bin/transmission-daemon').existsSync()) {
      return '/opt/homebrew/bin/transmission-daemon';
    }

    return bundledPath;  // Will fail with helpful error
  }

  Future<bool> startDaemon() async {
    final process = await Process.start(daemonPath, [
      '--config-dir', configDir,
      '--download-dir', downloadDir,
      '--port', '9091',
      '--no-auth',
    ]);

    _daemonProcess = process;
    _isRunning = true;
  }
}
```

**Quality:** ⭐⭐⭐⭐ (Good)
- ✅ Clean separation of concerns
- ✅ Handles bundled + system binaries
- ✅ Error handling

---

### 2. TransmissionClient [169 lines] ✅

**Purpose:** Transmission RPC client

```dart
class TransmissionClient {
  final String baseUrl = 'http://localhost:9091';
  String? _sessionId;  // CSRF token

  Future<Map<String, dynamic>> _rpcRequest(String method, {Map? arguments}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transmission/rpc'),
      headers: {
        'Content-Type': 'application/json',
        if (_sessionId != null) 'X-Transmission-Session-Id': _sessionId!,
      },
      body: json.encode({'method': method, 'arguments': arguments}),
    );

    // Handle 409 CSRF token refresh
    if (response.statusCode == 409) {
      _sessionId = response.headers['x-transmission-session-id'];
      return _rpcRequest(method, arguments: arguments);  // Retry
    }

    return json.decode(response.body)['arguments'];
  }

  // High-level methods
  Future<int> addTorrent({required String magnetLink}) { ... }
  Future<List<Torrent>> getTorrents() { ... }
  Future<void> removeTorrents({required List<int> ids}) { ... }
}
```

**Quality:** ⭐⭐⭐⭐⭐ (Excellent)
- ✅ Clean RPC abstraction
- ✅ CSRF token handling
- ✅ Type-safe methods

---

### 3. PlaybackService [278 lines] ✅

**Purpose:** Audio playback control

```dart
class PlaybackService extends ChangeNotifier {
  final Player _player = Player();

  Song? currentSong;
  List<Song> queue = [];
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  Future<void> play() async {
    if (currentSong == null) return;
    await _player.open(Media(currentSong!.path));
    await _player.play();
    isPlaying = true;
    notifyListeners();
  }

  void next() {
    if (queue.isEmpty) return;
    currentSong = queue.removeAt(0);
    play();
  }
}
```

**Quality:** ⭐⭐⭐⭐ (Good)
- ✅ Uses `media_kit` (MPV backend)
- ✅ Queue management
- ✅ ChangeNotifier for reactivity

---

## Models

### Song [232 lines]

```dart
class Song {
  final String path;
  final String title;
  final String artist;
  final String album;
  final int? year;

  // Audiophile details
  final String? codec;         // FLAC, MP3, AAC
  final String? bitrate;       // 320kbps, lossless
  final String? sampleRate;    // 44.1kHz, 96kHz
  final String? bitDepth;      // 16-bit, 24-bit

  // Metadata
  final DateTime dateAdded;
  int playCount = 0;

  // Favorites integration
  bool get isFavorite => favoritesService.isFavorite(path);
  int get rating => favoritesService.getRating(path);
}
```

**Quality:** ⭐⭐⭐⭐ (Good)
- ✅ Comprehensive metadata
- ✅ Audiophile details
- ✅ Factory constructor for JSON parsing

---

## Architecture Patterns

### State Management: **ChangeNotifier** (Basic)

```dart
// main.dart
final appSettings = AppSettings();  // Global singleton ❌
final favoritesService = FavoritesService();

// In widgets
appSettings.addListener(() {
  setState(() {});
});
```

**Issues:**
- 🔴 Global singletons (hard to test)
- ⚠️ No dependency injection
- ⚠️ Tight coupling

**Better Approach:**
```dart
// Use Riverpod or GetIt
final appSettingsProvider = Provider((ref) => AppSettings());

// In widgets
final settings = ref.watch(appSettingsProvider);
```

---

### Networking: **Direct HTTP/WebSocket** (No Repository)

```dart
// search_screen.dart
final response = await http.post(
  Uri.parse('${appSettings.searchApiUrl}/api/search'),
  body: json.encode({...})
);
```

**Issues:**
- ⚠️ No repository layer
- ⚠️ No caching
- ⚠️ No offline support

**Better Approach:**
```dart
// lib/repositories/search_repository.dart
class SearchRepository {
  final String baseUrl;
  final Dio _dio;  // Better HTTP client

  Future<List<TorrentResult>> search(String query) async {
    final response = await _dio.post('/api/search', data: {...});
    return (response.data['results'] as List)
        .map((json) => TorrentResult.fromJson(json))
        .toList();
  }
}
```

---

## Technical Debt Summary

### 🔴 Critical Issues

1. **LibraryScreen [1,059 lines]** - Needs immediate refactoring
   - Split into 5 files
   - Extract scanning to service
   - Add SQLite caching

2. **main.dart [947 lines]** - Too monolithic
   - Extract theme to `theme.dart`
   - Extract routing to `router.dart`
   - Move global singletons to DI

3. **Global Singletons** - Hard to test
   - Implement dependency injection (Riverpod/GetIt)

### ⚠️ Medium Issues

4. **No Repository Layer** - Direct HTTP calls everywhere
   - Create `SearchRepository`, `LibraryRepository`
   - Add caching, error handling, retries

5. **Untyped Data** - `Map<String, dynamic>` in search results
   - Use proper models everywhere

6. **No Database** - Everything in memory
   - Add SQLite via `drift` package
   - Cache library, favorites, ratings

### ✅ Strengths

- Clean service layer (transmission, playback)
- Good separation of screens
- Working audio player with MPV
- Comprehensive audiophile features

---

## Recommended Refactoring Plan

### Phase 1: Split Large Files (Week 1)

**1. Split LibraryScreen [1,059 → 200 lines]:**
```
lib/screens/library/
├── library_screen.dart          [200] - Container
├── song_list_view.dart          [300] - Songs table
├── album_grid_view.dart         [300] - Albums grid
└── widgets/
    ├── song_list_item.dart      [100]
    └── album_card.dart          [100]

lib/services/
└── library_service.dart         [200] - File scanning
```

**2. Split main.dart [947 → 300 lines]:**
```
lib/
├── main.dart                    [100] - Entry point only
├── app.dart                     [200] - Material app + routing
└── theme.dart                   [100] - Theme definitions
```

### Phase 2: Add State Management (Week 2)

**Migrate to Riverpod:**
```dart
// lib/providers/app_providers.dart
final appSettingsProvider = Provider((ref) => AppSettings());
final playbackProvider = ChangeNotifierProvider((ref) => PlaybackService());
final libraryProvider = StateNotifierProvider((ref) => LibraryNotifier());
```

**Benefits:**
- Testable (no global state)
- Better performance (selective rebuilds)
- Reactive (auto-updates)

### Phase 3: Add Repository Layer (Week 3)

```
lib/repositories/
├── search_repository.dart       # Search API client
├── library_repository.dart      # Local file scanning
└── settings_repository.dart     # Preferences + DB
```

**Add Caching:**
```dart
class SearchRepository {
  final Dio _dio;
  final Cache _cache;  // LRU cache

  Future<List<TorrentResult>> search(String query) async {
    // Check cache first
    final cached = _cache.get(query);
    if (cached != null) return cached;

    // Fetch from API
    final results = await _fetchFromApi(query);

    // Cache for 5 minutes
    _cache.set(query, results, ttl: Duration(minutes: 5));

    return results;
  }
}
```

### Phase 4: Add Database (Week 4)

```dart
// lib/database/database.dart
@DriftDatabase(tables: [Songs, Albums, Favorites, Ratings])
class MusicDatabase extends _$MusicDatabase {
  MusicDatabase() : super(_openConnection());

  // Queries
  Future<List<Song>> getAllSongs() => select(songs).get();
  Future<void> insertSong(Song song) => into(songs).insert(song);
}
```

**Benefits:**
- Instant app startup (no re-scanning)
- Offline library access
- Fast search/filter

---

## Conclusion

**Current State:** ⭐⭐⭐ (3/5)
- ✅ Works well for basic use
- ✅ Clean service layer
- ⚠️ Technical debt in UI layer
- 🔴 Doesn't scale to large libraries

**After Refactoring:** ⭐⭐⭐⭐⭐ (5/5)
- ✅ Modular, testable
- ✅ Fast (caching, database)
- ✅ Scalable to 10K+ songs
- ✅ Professional architecture

**Estimated Effort:** 4 weeks (1 developer)

---

**Next Steps:**
1. Start with LibraryScreen refactoring (biggest win)
2. Add Riverpod (infrastructure for future features)
3. Implement caching (immediate performance boost)
4. Add database (best UX improvement)
