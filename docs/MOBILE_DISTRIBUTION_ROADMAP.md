# TrustTune Mobile Distribution Roadmap

**Document Version**: 1.0
**Date**: November 2, 2025
**Status**: Planning Phase
**Author**: System Architecture Review

---

## Executive Summary

**TrustTune (KarmaPlayer)** is currently a desktop-only music discovery and playback application built with Flutter. This document assesses the feasibility of mobile distribution and provides a complete development roadmap.

### Key Findings

**✅ MOBILE DISTRIBUTION IS FEASIBLE**

However, it requires significant architectural changes and 12-20 weeks of development effort.

**Critical Success Factors:**
- Replace MediaKit (libmpv) with mobile-compatible audio players
- Either eliminate torrent support or implement mobile-friendly torrent libraries
- Migrate external binaries (yt-dlp, ffprobe) to platform-native APIs
- Implement mobile-specific background task management
- Adapt UI/UX for smaller screens and mobile interaction patterns

**Recommended Approach:**
1. **Phase 1**: iOS-first, YouTube streaming only (12-14 weeks)
2. **Phase 2**: Android port (4-6 weeks additional)
3. **Phase 3**: Add torrent support if viable (6-8 weeks additional)

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Mobile Feasibility Assessment](#mobile-feasibility-assessment)
3. [Technical Blockers](#technical-blockers)
4. [Architecture Migration Strategy](#architecture-migration-strategy)
5. [Development Roadmap](#development-roadmap)
6. [Detailed Task Breakdown](#detailed-task-breakdown)
7. [Risk Assessment](#risk-assessment)
8. [Timeline & Milestones](#timeline--milestones)
9. [Resource Requirements](#resource-requirements)
10. [App Store Considerations](#app-store-considerations)
11. [Decision Framework](#decision-framework)

---

## Current State Analysis

### Technology Stack

#### Frontend (Flutter Desktop)
```yaml
Flutter: 3.35.7
Dart: 3.9.2
Platforms: macOS, Windows, Linux (desktop only)
Code Size: ~14,258 lines Dart + 779 lines Swift + native C++
```

#### Critical Desktop-Only Dependencies
```yaml
# Audio Playback - BLOCKER
media_kit: ^1.1.11                    # libmpv wrapper - no mobile support
media_kit_libs_audio: ^1.0.2          # Desktop audio libs only

# File System - COMPATIBLE
path_provider: ^2.1.5                 # ✅ Has mobile support
file_picker: ^8.1.4                   # ✅ Has mobile support
shared_preferences: ^2.3.4            # ✅ Has mobile support

# Metadata - COMPATIBLE
metadata_god: ^1.1.0                  # ⚠️ May need alternative
sentry_flutter: ^8.11.0               # ✅ Full mobile support

# UI - COMPATIBLE
flutter_riverpod: ^2.6.1             # ✅ Cross-platform
go_router: ^14.6.2                    # ✅ Cross-platform
```

#### Backend (Python FastAPI)
- Runs locally on desktop (localhost:3000)
- Can be deployed remotely for mobile clients
- Already designed with remote deployment in mind

#### Bundled External Binaries - MAJOR BLOCKERS
1. **Transmission daemon** (~10MB) - Desktop-only BitTorrent client
2. **yt-dlp** (~15MB) - Python-based YouTube downloader
3. **ffprobe** (~70MB) - FFmpeg media analyzer

### Current Features

#### ✅ Mobile-Compatible Features (80% of UI)
- Album browsing and library view
- Music search interface
- Now Playing UI
- Queue management
- Favorites and ratings
- Settings screens
- Download progress tracking (UI only)

#### ❌ Desktop-Only Features (Require Replacement)
- Audio playback (MediaKit/libmpv)
- Torrent downloads (Transmission daemon)
- YouTube downloads (yt-dlp binary)
- Audio quality detection (ffprobe)
- Audio device selection (CoreAudio/WASAPI/PulseAudio)
- Direct file system access
- Background daemon management

---

## Mobile Feasibility Assessment

### Feasibility Matrix

| Component | iOS | Android | Effort | Priority |
|-----------|-----|---------|--------|----------|
| Flutter UI | ✅ 95% | ✅ 95% | Low | P0 |
| Audio Playback | ⚠️ Rewrite | ⚠️ Rewrite | High | P0 |
| YouTube Streaming | ⚠️ Proxy | ⚠️ Proxy | Medium | P0 |
| Torrent Downloads | ❌ Difficult | ⚠️ Possible | Very High | P2 |
| Background Tasks | ⚠️ Limited | ✅ Good | Medium | P1 |
| File Management | ⚠️ Scoped | ⚠️ Scoped | Medium | P1 |
| Metadata Reading | ✅ Native APIs | ✅ Native APIs | Low | P1 |
| Audio Device Selection | ❌ Not needed | ❌ Not needed | N/A | P3 |

**Legend:**
- ✅ = Works out of box
- ⚠️ = Requires modification
- ❌ = Significant blocker
- P0 = Must have, P1 = Should have, P2 = Nice to have, P3 = Can skip

### Overall Assessment

**iOS**: **⚠️ FEASIBLE WITH SIGNIFICANT EFFORT**
- Pros: Better audio APIs (AVFoundation), clearer app store guidelines
- Cons: Restrictive background execution, no torrent support realistically
- Estimated effort: 12-14 weeks (streaming only), 18-20 weeks (with torrents)

**Android**: **✅ MORE FEASIBLE**
- Pros: More flexible background tasks, ExoPlayer is excellent, torrent libs available
- Cons: Storage Access Framework complexity, more device fragmentation
- Estimated effort: 16-18 weeks total (after iOS)

**Recommendation**: **Start with iOS, streaming-only approach**

---

## Technical Blockers

### BLOCKER #1: Audio Playback (MediaKit/libmpv)

**Current Implementation:**
```dart
// Desktop code
import 'package:media_kit/media_kit.dart';

final player = Player();
await player.open(Media('file:///path/to/song.mp3'));
```

**Problem:**
- MediaKit wraps libmpv (desktop video player library)
- libmpv has no official mobile builds
- Binary size: ~50MB+ per platform
- Not designed for mobile power/memory constraints

**Mobile Solution:**

#### iOS - AVFoundation
```swift
import AVFoundation

class AudioPlayerService {
    private let player = AVPlayer()
    private let audioSession = AVAudioSession.sharedInstance()

    func play(url: URL) {
        try? audioSession.setCategory(.playback, mode: .default)
        try? audioSession.setActive(true)

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
    }
}
```

Flutter integration via `just_audio` package:
```dart
// Mobile code
import 'package:just_audio/just_audio.dart';

final player = AudioPlayer();
await player.setFilePath('/path/to/song.mp3');
await player.play();
```

#### Android - ExoPlayer
```kotlin
import com.google.android.exoplayer2.ExoPlayer

class AudioPlayerService {
    private val player = ExoPlayer.Builder(context).build()

    fun play(uri: Uri) {
        val mediaItem = MediaItem.fromUri(uri)
        player.setMediaItem(mediaItem)
        player.prepare()
        player.play()
    }
}
```

**Migration Strategy:**
1. Create abstraction layer: `AudioPlayerInterface`
2. Implement desktop version: `MediaKitPlayer implements AudioPlayerInterface`
3. Implement mobile version: `JustAudioPlayer implements AudioPlayerInterface`
4. Use conditional imports or dependency injection
5. Migrate all playback logic to use abstraction

**Effort**: 3-4 weeks
**Risk**: Medium - well-documented APIs

---

### BLOCKER #2: Torrent Downloads (Transmission Daemon)

**Current Implementation:**
```python
# Python backend
import transmission_rpc

client = transmission_rpc.Client(host='localhost', port=9091)
torrent = client.add_torrent(magnet_link)
```

**Problem:**
- Transmission is a desktop daemon (requires separate process)
- No official mobile builds
- iOS: Background execution extremely limited
- Battery drain concerns
- Data usage concerns

**Mobile Solutions:**

#### Option A: Remove Torrents (RECOMMENDED for MVP)
- Focus on YouTube streaming only
- Simpler, faster to market
- Better mobile UX (no downloads, no storage)
- Avoid legal gray areas in app stores

**Pros:**
- 6 weeks faster development
- Lower battery usage
- No storage management needed
- Clearer app store compliance

**Cons:**
- Lose high-quality FLAC downloads
- Less differentiation from competitors

#### Option B: Android-Only Torrents (COMPROMISE)
```kotlin
// Android with libtorrent4j
import org.libtorrent4j.TorrentHandle
import org.libtorrent4j.SessionManager

class TorrentService : Service() {
    private val sessionManager = SessionManager()

    fun addTorrent(magnetLink: String) {
        sessionManager.download(magnetLink, File("/storage"))
    }
}
```

**Pros:**
- Keep core feature on Android
- Android has better background support

**Cons:**
- Platform fragmentation (iOS vs Android features)
- iOS users get inferior experience
- 6 weeks additional development

#### Option C: Cloud Proxy (INNOVATIVE)
- Backend server downloads torrents
- Mobile streams from backend
- Backend can run on user's home server/NAS

**Architecture:**
```
Mobile App -> WebSocket -> Backend Server -> Transmission
                                           -> Serves files via HTTP
```

**Pros:**
- Works on both iOS and Android
- No battery drain on mobile
- No storage constraints
- Can leverage desktop infrastructure

**Cons:**
- Requires network connectivity
- More complex architecture
- Backend hosting requirements

**Effort:**
- Option A: 0 weeks (remove feature)
- Option B: 6-8 weeks
- Option C: 4-5 weeks

**Recommendation**: Start with Option A (streaming-only), add Option C later if needed

---

### BLOCKER #3: YouTube Downloads (yt-dlp)

**Current Implementation:**
```python
# Python backend
import yt_dlp

ydl_opts = {'format': 'bestaudio'}
with yt_dlp.YoutubeDL(ydl_opts) as ydl:
    info = ydl.extract_info(url, download=True)
```

**Problem:**
- yt-dlp is a Python CLI tool (~15MB)
- No official mobile builds
- Requires Python interpreter
- YouTube frequently changes, needs updates

**Mobile Solutions:**

#### Option A: Server-Side Proxy (RECOMMENDED)
```python
# Backend API endpoint
@app.post("/api/youtube/stream-url")
async def get_stream_url(video_id: str):
    """Backend extracts URL, mobile streams directly"""
    ydl_opts = {'format': 'bestaudio', 'quiet': True}
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(f"https://youtube.com/watch?v={video_id}", download=False)
        return {"url": info['url']}
```

```dart
// Mobile client
class YouTubeService {
  Future<String> getStreamUrl(String videoId) async {
    final response = await http.post('/api/youtube/stream-url',
      body: {'video_id': videoId}
    );
    return response['url'];
  }
}
```

**Pros:**
- Backend handles all complexity
- Mobile just streams URL
- Easy to update yt-dlp version
- Works on all platforms

**Cons:**
- Requires backend connectivity
- Backend hosting cost
- Potential legal concerns (ToS violation)

#### Option B: Native Flutter Package
```dart
// Use youtube_explode_dart (pure Dart)
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final yt = YoutubeExplode();
final manifest = await yt.videos.streamsClient.getManifest(videoId);
final streamInfo = manifest.audioOnly.withHighestBitrate();
final streamUrl = streamInfo.url;
```

**Pros:**
- No backend required
- Pure Dart (cross-platform)
- Lighter weight

**Cons:**
- Less robust than yt-dlp
- May break when YouTube changes
- Limited format support

**Effort:**
- Option A: 1-2 weeks
- Option B: 2-3 weeks

**Recommendation**: Option A for reliability, Option B as fallback

---

### BLOCKER #4: Audio Quality Detection (ffprobe)

**Current Implementation:**
```python
# Python backend
import subprocess

result = subprocess.run([
    'ffprobe', '-v', 'quiet', '-print_format', 'json',
    '-show_format', '-show_streams', audio_file
], capture_output=True)
```

**Problem:**
- ffprobe is 70MB binary
- Desktop-only builds
- Subprocess execution

**Mobile Solutions:**

#### iOS - AVAssetReader
```swift
import AVFoundation

func getAudioMetadata(url: URL) -> AudioMetadata? {
    let asset = AVAsset(url: url)

    guard let track = asset.tracks(withMediaType: .audio).first else {
        return nil
    }

    let format = track.formatDescriptions.first as! CMAudioFormatDescription
    let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(format)

    return AudioMetadata(
        sampleRate: basicDescription?.pointee.mSampleRate ?? 0,
        bitRate: track.estimatedDataRate,
        channels: Int(basicDescription?.pointee.mChannelsPerFrame ?? 0)
    )
}
```

#### Android - MediaMetadataRetriever
```kotlin
import android.media.MediaMetadataRetriever

fun getAudioMetadata(path: String): AudioMetadata {
    val retriever = MediaMetadataRetriever()
    retriever.setDataSource(path)

    return AudioMetadata(
        sampleRate = retriever.extractMetadata(METADATA_KEY_SAMPLERATE)?.toInt(),
        bitRate = retriever.extractMetadata(METADATA_KEY_BITRATE)?.toInt(),
        duration = retriever.extractMetadata(METADATA_KEY_DURATION)?.toLong()
    )
}
```

**Effort**: 1-2 weeks
**Risk**: Low - platform APIs are stable

---

### BLOCKER #5: File System Access

**Current Implementation:**
```dart
// Desktop - direct access
final musicDir = Directory('/Users/username/Music');
final files = musicDir.listSync(recursive: true);
```

**Problem:**
- Mobile has scoped storage
- Can't freely access file system
- Different permissions model

**Mobile Solutions:**

#### iOS - Document Picker
```dart
import 'package:file_picker/file_picker.dart';

class MobileFileService {
  Future<String?> pickMusicFolder() async {
    // iOS: User grants access to specific folder
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      // Save bookmark for persistent access
      await saveBookmark(selectedDirectory);
    }

    return selectedDirectory;
  }

  Future<List<FileSystemEntity>> scanMusicLibrary(String path) async {
    final dir = Directory(path);
    return dir.listSync(recursive: true)
        .where((e) => e.path.endsWith('.mp3') ||
                      e.path.endsWith('.flac'))
        .toList();
  }
}
```

#### Android - Storage Access Framework
```kotlin
// Request scoped directory access
val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
startActivityForResult(intent, REQUEST_CODE)

// In onActivityResult
fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    if (requestCode == REQUEST_CODE && resultCode == RESULT_OK) {
        val treeUri = data?.data

        // Persist permission
        contentResolver.takePersistableUriPermission(
            treeUri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION
        )
    }
}
```

**Migration Strategy:**
1. Abstract file access: `FileSystemService` interface
2. Desktop: Direct file system access
3. Mobile: Document picker + scoped access
4. Shared: SQLite database for file metadata (avoid rescanning)

**Effort**: 2-3 weeks
**Risk**: Medium - permissions can be confusing for users

---

### BLOCKER #6: Background Execution

**Current Implementation:**
```python
# Desktop - daemon runs freely
daemon = TransmissionDaemon()
daemon.start()  # Runs until killed
```

**Problem:**
- iOS: Very limited background execution (10-30 minutes max)
- Android: Better, but still restricted
- Battery optimization kills background tasks

**Mobile Solutions:**

#### iOS - Background Audio + URLSession
```swift
// Register background audio capability
let audioSession = AVAudioSession.sharedInstance()
try? audioSession.setCategory(.playback, mode: .default)

// For downloads
let config = URLSessionConfiguration.background(withIdentifier: "music-downloads")
let session = URLSession(configuration: config)

// Downloads continue even if app is killed
let task = session.downloadTask(with: url)
task.resume()
```

#### Android - Foreground Service
```kotlin
class DownloadService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Show persistent notification
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Downloading music")
            .setSmallIcon(R.drawable.ic_download)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        // Perform download
        downloadManager.download(url)

        return START_STICKY
    }
}
```

**Key Constraints:**
- iOS: Can only run background tasks for active audio or downloads
- Android: Must show notification for foreground service
- Both: System can still kill if memory pressure

**Migration Strategy:**
1. Move from continuous daemon to task-based downloads
2. Use platform background APIs
3. Add retry logic for interrupted tasks
4. Show clear user notifications

**Effort**: 2-3 weeks
**Risk**: High - background execution is fragile on mobile

---

## Architecture Migration Strategy

### Current Architecture (Desktop)

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Desktop App                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   UI Layer   │  │   Services   │  │   Models     │  │
│  │ (Riverpod)   │  │ (Business)   │  │   (Data)     │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│         │                  │                  │          │
│         └──────────────────┴──────────────────┘          │
│                           │                              │
│                  ┌────────▼────────┐                     │
│                  │  MediaKit/MPV   │ (Audio Playback)    │
│                  └─────────────────┘                     │
└───────────────────────────┬─────────────────────────────┘
                            │ WebSocket/HTTP
                            │
┌───────────────────────────▼─────────────────────────────┐
│                   Python FastAPI Backend                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │Search Engine │  │Download Mgr  │  │Metadata Svc  │  │
│  │(Multi-source)│  │(Transmission)│  │(MusicBrainz) │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│         │                  │                  │          │
│         ▼                  ▼                  ▼          │
│   [Jackett]         [Transmission]      [ffprobe]       │
│   [1337x]           [yt-dlp]            [MusicBrainz]   │
│   [YouTube]                                              │
└──────────────────────────────────────────────────────────┘
```

### Target Architecture (Mobile)

```
┌─────────────────────────────────────────────────────────┐
│                  Flutter Mobile App                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   UI Layer   │  │   Services   │  │   Models     │  │
│  │ (Riverpod)   │◄─┤ (Business)   │◄─┤   (Data)     │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│         │                  │                             │
│         │          ┌───────┴─────────┐                  │
│         │          │                 │                  │
│         │     ┌────▼─────┐    ┌─────▼──────┐           │
│         │     │Platform  │    │ Platform   │           │
│         │     │Audio Svc │    │ File Svc   │           │
│         │     │(iOS/And) │    │(iOS/And)   │           │
│         │     └────┬─────┘    └─────┬──────┘           │
│         │          │                 │                  │
│  ┌──────▼──────────▼─────────────────▼──────┐          │
│  │      Abstraction Layer (Interfaces)       │          │
│  │  - AudioPlayer                            │          │
│  │  - FileSystem                             │          │
│  │  - BackgroundTask                         │          │
│  │  - MetadataReader                         │          │
│  └───────────────────────────────────────────┘          │
└───────────────────────────┬─────────────────────────────┘
                            │ HTTPS/WebSocket
                            │
┌───────────────────────────▼─────────────────────────────┐
│             Cloud Backend (Remote Deployment)            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │Search Engine │  │  YouTube     │  │Metadata Svc  │  │
│  │(Multi-source)│  │  Proxy       │  │(MusicBrainz) │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│         │                  │                  │          │
│         ▼                  ▼                  ▼          │
│   [Jackett]           [yt-dlp]          [MusicBrainz]   │
│   [1337x]             [FFmpeg]          [Discogs]       │
│   [YouTube Music]                                        │
│                                                          │
│   Optional: User's Home Server for Torrents             │
│   ┌──────────────────────────────────┐                 │
│   │  Transmission (Desktop/NAS)      │                 │
│   │  → Serves files via HTTP         │                 │
│   └──────────────────────────────────┘                 │
└──────────────────────────────────────────────────────────┘
```

### Key Architectural Changes

#### 1. Abstraction Layer Pattern

**Before:**
```dart
// Tight coupling to MediaKit
import 'package:media_kit/media_kit.dart';

class PlaybackService {
  final Player _player = Player();

  void play(String path) {
    _player.open(Media(path));
  }
}
```

**After:**
```dart
// Abstraction layer
abstract class AudioPlayerInterface {
  Future<void> play(String path);
  Future<void> pause();
  Future<void> seek(Duration position);
  Stream<PlayerState> get stateStream;
}

// Desktop implementation
class DesktopAudioPlayer implements AudioPlayerInterface {
  final Player _player = Player();
  // ... MediaKit implementation
}

// Mobile implementation
class MobileAudioPlayer implements AudioPlayerInterface {
  final AudioPlayer _player = AudioPlayer();
  // ... JustAudio implementation
}

// Service uses abstraction
class PlaybackService {
  final AudioPlayerInterface _player;

  PlaybackService(this._player); // Dependency injection

  void play(String path) {
    _player.play(path);
  }
}
```

#### 2. Platform-Specific Services

```dart
// lib/services/platform/audio_service.dart
abstract class PlatformAudioService {
  factory PlatformAudioService() {
    if (Platform.isIOS) {
      return IOSAudioService();
    } else if (Platform.isAndroid) {
      return AndroidAudioService();
    } else {
      return DesktopAudioService();
    }
  }

  Future<void> initialize();
  AudioPlayerInterface createPlayer();
  Future<AudioMetadata> getMetadata(String path);
}
```

#### 3. Feature Flags

```dart
class FeatureFlags {
  static bool get supportsTorrents {
    return Platform.isAndroid || Platform.isLinux ||
           Platform.isMacOS || Platform.isWindows;
  }

  static bool get supportsLocalFiles {
    return !Platform.isIOS; // iOS has limited file access
  }

  static bool get supportsBackgroundDownloads {
    return Platform.isAndroid; // More reliable on Android
  }
}
```

#### 4. Backend Communication Strategy

```dart
class BackendConfig {
  static String get baseUrl {
    if (kIsWeb || Platform.isIOS || Platform.isAndroid) {
      // Mobile: Use remote backend
      return const String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: 'https://api.trusttune.app'
      );
    } else {
      // Desktop: Use local backend
      return 'http://localhost:3000';
    }
  }
}
```

---

## Development Roadmap

### Phase 1: Foundation (Weeks 1-4)

**Goal**: Create abstraction layer and platform detection

#### Week 1: Architecture Setup
- [ ] Create abstraction interfaces (AudioPlayer, FileSystem, MetadataReader)
- [ ] Set up dependency injection (get_it or riverpod providers)
- [ ] Implement feature flags
- [ ] Create platform detection utilities
- [ ] Set up iOS/Android project structures

#### Week 2: Audio Abstraction
- [ ] Define `AudioPlayerInterface` with all required methods
- [ ] Implement `DesktopAudioPlayer` (MediaKit wrapper)
- [ ] Add unit tests for abstraction layer
- [ ] Update PlaybackService to use abstraction
- [ ] Verify desktop functionality still works

#### Week 3: File System Abstraction
- [ ] Define `FileSystemService` interface
- [ ] Implement desktop version (direct access)
- [ ] Add mock implementation for testing
- [ ] Update all file access code to use service
- [ ] Add file caching layer

#### Week 4: Backend Communication
- [ ] Implement configurable backend URL
- [ ] Add environment-based configuration
- [ ] Test with remote backend deployment
- [ ] Add offline mode detection
- [ ] Implement request retry logic

**Deliverables:**
- ✅ Abstraction layer in place
- ✅ Desktop build still functional
- ✅ Foundation for mobile implementation
- ✅ CI/CD updated for multi-platform

---

### Phase 2: iOS Audio Implementation (Weeks 5-8)

**Goal**: Get music playback working on iOS

#### Week 5: iOS Setup
- [ ] Create iOS project structure
- [ ] Configure Info.plist (background audio, file access)
- [ ] Set up CocoaPods dependencies
- [ ] Install just_audio package
- [ ] Create Swift<->Dart bridge

#### Week 6: Audio Player Implementation
- [ ] Implement `IOSAudioPlayer` using just_audio
- [ ] Configure AVAudioSession for background playback
- [ ] Add remote control (lock screen controls)
- [ ] Implement playback state management
- [ ] Add error handling

#### Week 7: Integration & Testing
- [ ] Wire up PlaybackService to iOS implementation
- [ ] Test play/pause/seek/volume controls
- [ ] Test background playback
- [ ] Test interruption handling (calls, alarms)
- [ ] Test audio ducking

#### Week 8: Metadata & UI Polish
- [ ] Implement iOS metadata reader (AVAsset)
- [ ] Add now playing info to lock screen
- [ ] Update UI for iOS guidelines
- [ ] Add gesture controls
- [ ] Test on physical devices

**Deliverables:**
- ✅ iOS app plays local music files
- ✅ Background audio works
- ✅ Lock screen controls functional
- ✅ Basic UI adapted for iOS

---

### Phase 3: iOS YouTube Streaming (Weeks 9-11)

**Goal**: YouTube streaming functionality on iOS

#### Week 9: YouTube Backend Proxy
- [ ] Create `/api/youtube/search` endpoint
- [ ] Create `/api/youtube/stream-url` endpoint
- [ ] Implement yt-dlp URL extraction
- [ ] Add caching layer (Redis/in-memory)
- [ ] Deploy to cloud (Railway/Fly.io)

#### Week 10: iOS YouTube Client
- [ ] Create YouTubeService in Flutter
- [ ] Implement search UI
- [ ] Stream URL playback
- [ ] Add search history
- [ ] Implement "add to library" flow

#### Week 11: Download & Offline
- [ ] Implement URLSession background downloads
- [ ] Add download progress UI
- [ ] Store downloaded files with metadata
- [ ] Add offline playback mode
- [ ] Implement download queue

**Deliverables:**
- ✅ YouTube search works on iOS
- ✅ Streaming playback functional
- ✅ Background downloads work
- ✅ Offline mode available

---

### Phase 4: iOS File Management (Weeks 12-13)

**Goal**: Local library management on iOS

#### Week 12: File Access
- [ ] Implement document picker
- [ ] Create iOS file system service
- [ ] Add persistent access bookmarks
- [ ] Implement recursive directory scanning
- [ ] Add file import flow

#### Week 13: Library Features
- [ ] Implement local library database (SQLite)
- [ ] Add album/artist grouping
- [ ] Implement search & filter
- [ ] Add favorites/ratings
- [ ] Create playlist management

**Deliverables:**
- ✅ Users can import local music
- ✅ Library browsing works
- ✅ Metadata extraction functional
- ✅ Playlists/favorites work

---

### Phase 5: iOS Beta Release (Week 14)

**Goal**: Submit iOS app to TestFlight

#### Tasks
- [ ] Complete iOS app icon & splash screen
- [ ] Write App Store description
- [ ] Create screenshots for all device sizes
- [ ] Configure app signing & provisioning
- [ ] Set up In-App Purchase (if applicable)
- [ ] Complete privacy policy
- [ ] Test on all iOS versions (iOS 14+)
- [ ] Submit to TestFlight
- [ ] Recruit beta testers
- [ ] Gather feedback

**Deliverables:**
- ✅ iOS app in TestFlight
- ✅ Beta testing begun
- ✅ Feedback loop established

---

### Phase 6: Android Port (Weeks 15-18)

**Goal**: Adapt iOS implementation for Android

#### Week 15: Android Setup
- [ ] Create Android project structure
- [ ] Configure AndroidManifest.xml (permissions)
- [ ] Set up Gradle dependencies
- [ ] Install just_audio package
- [ ] Create Kotlin<->Dart bridge

#### Week 16: Audio Implementation
- [ ] Implement `AndroidAudioPlayer` using just_audio
- [ ] Configure MediaSession for notifications
- [ ] Add lock screen controls
- [ ] Test background playback
- [ ] Handle audio focus changes

#### Week 17: File & Storage
- [ ] Implement Storage Access Framework
- [ ] Add scoped directory access
- [ ] Create Android file service
- [ ] Test on Android 11+ (scoped storage)
- [ ] Add file picker UI

#### Week 18: Features & Testing
- [ ] Port YouTube functionality
- [ ] Implement background downloads (WorkManager)
- [ ] Add foreground service notification
- [ ] Test on multiple devices/Android versions
- [ ] Performance optimization

**Deliverables:**
- ✅ Android app feature parity with iOS
- ✅ Tested on Android 10, 11, 12, 13, 14
- ✅ Ready for beta testing

---

### Phase 7: Android Beta (Week 19)

**Goal**: Android beta release

#### Tasks
- [ ] Create Android app icon (adaptive)
- [ ] Generate Play Store assets
- [ ] Configure app signing (upload key)
- [ ] Write Play Store listing
- [ ] Complete content rating questionnaire
- [ ] Submit to internal testing track
- [ ] Submit to closed beta track
- [ ] Gather feedback

**Deliverables:**
- ✅ Android app in Play Store beta
- ✅ Beta testing active
- ✅ Crash reports configured (Sentry)

---

### Phase 8: Polish & Production (Weeks 20-22)

**Goal**: Production-ready apps for both platforms

#### Week 20: Bug Fixes
- [ ] Address beta tester feedback
- [ ] Fix crash reports
- [ ] Performance optimization
- [ ] Memory leak fixes
- [ ] Battery usage optimization

#### Week 21: Features & UX
- [ ] Add onboarding tutorial
- [ ] Implement rate limiting (backend)
- [ ] Add user analytics (privacy-respecting)
- [ ] Improve error messages
- [ ] Add help/support section

#### Week 22: Launch Prep
- [ ] Final QA testing
- [ ] App Store review preparation
- [ ] Marketing materials
- [ ] Press kit
- [ ] Launch announcement
- [ ] Submit to App Store & Play Store

**Deliverables:**
- ✅ Both apps approved and live
- ✅ Launch materials ready
- ✅ Support channels established

---

## Detailed Task Breakdown

### Task Category: Audio Playback Migration

#### Task 1.1: Create AudioPlayerInterface
**Estimated Time**: 4 hours
**Priority**: P0
**Dependencies**: None

**Description:**
Create abstract interface that defines all audio playback operations.

**Acceptance Criteria:**
- [ ] Interface defines: play, pause, stop, seek, setVolume, setSpeed
- [ ] Includes state stream (playing, paused, buffering, error)
- [ ] Includes position stream (current playback position)
- [ ] Includes duration property
- [ ] Includes playlist/queue methods
- [ ] Has comprehensive documentation
- [ ] Unit test stubs created

**Code Template:**
```dart
abstract class AudioPlayerInterface {
  /// Initialize the player
  Future<void> initialize();

  /// Load and play audio from path/URL
  Future<void> play(String source);

  /// Pause playback
  Future<void> pause();

  /// Resume playback
  Future<void> resume();

  /// Stop playback and release resources
  Future<void> stop();

  /// Seek to position
  Future<void> seek(Duration position);

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume);

  /// Set playback speed (0.5 to 2.0)
  Future<void> setSpeed(double speed);

  /// Current playback state
  Stream<PlayerState> get stateStream;

  /// Current position
  Stream<Duration> get positionStream;

  /// Track duration
  Duration? get duration;

  /// Dispose player
  Future<void> dispose();
}

enum PlayerState {
  idle,
  loading,
  buffering,
  playing,
  paused,
  completed,
  error
}
```

#### Task 1.2: Implement DesktopAudioPlayer
**Estimated Time**: 8 hours
**Priority**: P0
**Dependencies**: Task 1.1

**Description:**
Wrap existing MediaKit implementation in new interface.

**Acceptance Criteria:**
- [ ] All interface methods implemented
- [ ] Maintains existing functionality
- [ ] No breaking changes to current behavior
- [ ] Error handling preserved
- [ ] Tests pass
- [ ] Desktop platforms (macOS/Windows/Linux) verified

#### Task 1.3: Implement MobileAudioPlayer (iOS)
**Estimated Time**: 16 hours
**Priority**: P0
**Dependencies**: Task 1.1

**Description:**
Implement audio player for iOS using just_audio package.

**Acceptance Criteria:**
- [ ] just_audio integrated
- [ ] All interface methods implemented
- [ ] Background audio configured (AVAudioSession)
- [ ] Lock screen controls working
- [ ] Handles interruptions (calls, alarms)
- [ ] Tests on physical iOS device
- [ ] Memory leaks checked (Instruments)

**Technical Notes:**
```dart
import 'package:just_audio/just_audio.dart';

class IOSAudioPlayer implements AudioPlayerInterface {
  final AudioPlayer _player = AudioPlayer();
  final _stateController = StreamController<PlayerState>.broadcast();

  @override
  Future<void> initialize() async {
    // Configure audio session
    await AudioSession.instance.then((session) async {
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
      ));
    });

    // Listen to player state
    _player.playerStateStream.listen((state) {
      _stateController.add(_mapState(state));
    });
  }

  @override
  Future<void> play(String source) async {
    try {
      if (source.startsWith('http')) {
        await _player.setUrl(source);
      } else {
        await _player.setFilePath(source);
      }
      await _player.play();
    } catch (e) {
      _stateController.add(PlayerState.error);
      rethrow;
    }
  }

  // ... other methods
}
```

#### Task 1.4: Implement MobileAudioPlayer (Android)
**Estimated Time**: 16 hours
**Priority**: P1
**Dependencies**: Task 1.1, Task 1.3

**Description:**
Implement audio player for Android using just_audio package.

**Acceptance Criteria:**
- [ ] All interface methods implemented
- [ ] MediaSession configured for notifications
- [ ] Lock screen controls working
- [ ] Handles audio focus changes
- [ ] Tests on multiple Android versions (10, 11, 12, 13)
- [ ] Works with Bluetooth devices

#### Task 1.5: Update PlaybackService
**Estimated Time**: 8 hours
**Priority**: P0
**Dependencies**: Task 1.2, Task 1.3, Task 1.4

**Description:**
Refactor PlaybackService to use abstraction layer.

**Acceptance Criteria:**
- [ ] Uses dependency injection
- [ ] Works on all platforms (desktop + mobile)
- [ ] Existing features preserved
- [ ] No UI changes required
- [ ] Tests updated and passing
- [ ] Code coverage maintained

**Refactoring Example:**
```dart
// Before
class PlaybackService extends ChangeNotifier {
  final Player _player = Player();

  void play(String path) {
    _player.open(Media(path));
  }
}

// After
class PlaybackService extends ChangeNotifier {
  final AudioPlayerInterface _player;

  // Dependency injection
  PlaybackService(this._player);

  void play(String path) {
    _player.play(path);
  }
}

// In main.dart
void main() {
  final AudioPlayerInterface player;

  if (Platform.isIOS || Platform.isAndroid) {
    player = MobileAudioPlayer();
  } else {
    player = DesktopAudioPlayer();
  }

  runApp(MyApp(
    playbackService: PlaybackService(player),
  ));
}
```

---

### Task Category: YouTube Integration

#### Task 2.1: Backend YouTube Proxy API
**Estimated Time**: 12 hours
**Priority**: P0
**Dependencies**: None

**Description:**
Create FastAPI endpoints for YouTube search and stream URL extraction.

**Acceptance Criteria:**
- [ ] `/api/youtube/search` endpoint returns search results
- [ ] `/api/youtube/stream-url` returns direct audio stream URL
- [ ] Results cached for 1 hour (Redis or in-memory)
- [ ] Rate limiting implemented (10 requests/minute per user)
- [ ] Error handling for YouTube API changes
- [ ] Tests for all endpoints
- [ ] Deployed to cloud (Railway/Fly.io)

**Code Template:**
```python
from fastapi import FastAPI, HTTPException
from yt_dlp import YoutubeDL
from cachetools import TTLCache
import asyncio

app = FastAPI()

# Cache stream URLs for 1 hour
stream_cache = TTLCache(maxsize=1000, ttl=3600)

@app.get("/api/youtube/search")
async def search_youtube(query: str, limit: int = 10):
    """Search YouTube Music for songs"""
    try:
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': True
        }

        with YoutubeDL(ydl_opts) as ydl:
            results = ydl.extract_info(
                f"ytsearch{limit}:{query}",
                download=False
            )

        return {
            'results': [
                {
                    'id': entry['id'],
                    'title': entry['title'],
                    'artist': entry.get('uploader', 'Unknown'),
                    'duration': entry.get('duration', 0),
                    'thumbnail': entry.get('thumbnail')
                }
                for entry in results.get('entries', [])
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/youtube/stream-url")
async def get_stream_url(video_id: str):
    """Get direct audio stream URL for YouTube video"""
    # Check cache first
    if video_id in stream_cache:
        return stream_cache[video_id]

    try:
        ydl_opts = {
            'format': 'bestaudio/best',
            'quiet': True,
            'no_warnings': True
        }

        with YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(
                f"https://youtube.com/watch?v={video_id}",
                download=False
            )

        result = {
            'url': info['url'],
            'ext': info.get('ext', 'mp3'),
            'quality': info.get('abr', 128),
            'expires_in': 3600  # URL valid for 1 hour
        }

        # Cache result
        stream_cache[video_id] = result

        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

#### Task 2.2: Flutter YouTube Service
**Estimated Time**: 8 hours
**Priority**: P0
**Dependencies**: Task 2.1

**Description:**
Create Flutter service to communicate with YouTube backend API.

**Acceptance Criteria:**
- [ ] Search functionality working
- [ ] Stream URL retrieval working
- [ ] Error handling for network failures
- [ ] Retry logic implemented
- [ ] Offline mode detection
- [ ] Unit tests for service
- [ ] Integration tests with mock backend

**Code Template:**
```dart
class YouTubeService {
  final String baseUrl;
  final http.Client client;

  YouTubeService({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  Future<List<YouTubeResult>> search(String query) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/youtube/search')
            .replace(queryParameters: {'query': query})
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['results'] as List)
            .map((e) => YouTubeResult.fromJson(e))
            .toList();
      } else {
        throw YouTubeException('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is SocketException) {
        throw YouTubeException('No internet connection');
      }
      rethrow;
    }
  }

  Future<String> getStreamUrl(String videoId) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/youtube/stream-url'),
      body: json.encode({'video_id': videoId}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['url'];
    } else {
      throw YouTubeException('Failed to get stream URL');
    }
  }
}
```

#### Task 2.3: YouTube Search UI
**Estimated Time**: 12 hours
**Priority**: P1
**Dependencies**: Task 2.2

**Description:**
Create YouTube search interface in Flutter app.

**Acceptance Criteria:**
- [ ] Search bar with debounced input
- [ ] Grid view of search results
- [ ] Thumbnail loading with caching
- [ ] Play button on each result
- [ ] Add to library button
- [ ] Loading states
- [ ] Empty states
- [ ] Error states with retry

#### Task 2.4: YouTube Background Downloads
**Estimated Time**: 16 hours
**Priority**: P1
**Dependencies**: Task 2.2

**Description:**
Implement background downloads for YouTube tracks on mobile.

**iOS Implementation:**
```swift
// URLSession background configuration
let config = URLSessionConfiguration.background(
    withIdentifier: "com.trusttune.downloads"
)
config.sessionSendsLaunchEvents = true

let session = URLSession(
    configuration: config,
    delegate: downloadDelegate,
    delegateQueue: nil
)

// Start download
let task = session.downloadTask(with: url)
task.resume()
```

**Android Implementation:**
```kotlin
// WorkManager for background downloads
val downloadWork = OneTimeWorkRequestBuilder<DownloadWorker>()
    .setInputData(workDataOf("url" to streamUrl))
    .setConstraints(
        Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
    )
    .build()

WorkManager.getInstance(context).enqueue(downloadWork)
```

**Acceptance Criteria:**
- [ ] Downloads continue in background
- [ ] Resume after app kill
- [ ] Progress notifications
- [ ] Battery optimization
- [ ] WiFi-only option
- [ ] Download queue management

---

### Task Category: File System Migration

#### Task 3.1: FileSystemService Interface
**Estimated Time**: 4 hours
**Priority**: P0
**Dependencies**: None

**Description:**
Create abstraction for file system operations.

**Code Template:**
```dart
abstract class FileSystemService {
  /// Request access to music directory
  Future<String?> requestMusicDirectory();

  /// Scan directory for music files
  Future<List<AudioFile>> scanDirectory(String path);

  /// Read file metadata
  Future<AudioMetadata> getMetadata(String path);

  /// Import file to library
  Future<String> importFile(String sourcePath);

  /// Delete file from library
  Future<void> deleteFile(String path);

  /// Check if path is accessible
  Future<bool> hasAccess(String path);
}
```

#### Task 3.2: Desktop FileSystemService
**Estimated Time**: 4 hours
**Priority**: P0
**Dependencies**: Task 3.1

**Description:**
Implement desktop version with direct file access.

**Acceptance Criteria:**
- [ ] All methods implemented
- [ ] Works on macOS, Windows, Linux
- [ ] Handles permissions errors
- [ ] Tests passing

#### Task 3.3: iOS FileSystemService
**Estimated Time**: 12 hours
**Priority**: P0
**Dependencies**: Task 3.1

**Description:**
Implement iOS version using document picker and scoped access.

**Implementation:**
```swift
import UniformTypeIdentifiers

class IOSFileSystemService {
    func requestMusicDirectory() async -> URL? {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.folder]
        )

        // Present picker and wait for selection
        // ...

        if let url = selectedURL {
            // Request security-scoped access
            guard url.startAccessingSecurityScopedResource() else {
                return nil
            }

            // Save bookmark for persistent access
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            UserDefaults.standard.set(bookmark, forKey: "musicFolderBookmark")

            return url
        }

        return nil
    }

    func scanDirectory(url: URL) async -> [AudioFile] {
        var files: [AudioFile] = []

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url,
            includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "mp3" ||
               fileURL.pathExtension == "flac" {
                files.append(AudioFile(url: fileURL))
            }
        }

        return files
    }
}
```

**Acceptance Criteria:**
- [ ] Document picker shows and works
- [ ] Bookmark persistence works
- [ ] Recursive scanning works
- [ ] Handles permissions correctly
- [ ] Tests on physical device

#### Task 3.4: Android FileSystemService
**Estimated Time**: 12 hours
**Priority**: P1
**Dependencies**: Task 3.1

**Description:**
Implement Android version using Storage Access Framework.

**Acceptance Criteria:**
- [ ] SAF picker integration
- [ ] Persistent URI permissions
- [ ] Scoped storage compliance (Android 11+)
- [ ] Recursive directory access
- [ ] Tests on Android 10, 11, 12, 13

---

### Task Category: Background Execution

#### Task 4.1: iOS Background Audio
**Estimated Time**: 8 hours
**Priority**: P0
**Dependencies**: Audio player implementation

**Description:**
Configure iOS app for background audio playback.

**Configuration (Info.plist):**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

**Code:**
```swift
// Configure audio session
let session = AVAudioSession.sharedInstance()
try? session.setCategory(.playback, mode: .default)
try? session.setActive(true)

// Configure remote commands
let commandCenter = MPRemoteCommandCenter.shared()

commandCenter.playCommand.addTarget { event in
    self.player.play()
    return .success
}

commandCenter.pauseCommand.addTarget { event in
    self.player.pause()
    return .success
}

// Update now playing info
var nowPlayingInfo = [String: Any]()
nowPlayingInfo[MPMediaItemPropertyTitle] = currentSong.title
nowPlayingInfo[MPMediaItemPropertyArtist] = currentSong.artist
nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration

MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
```

**Acceptance Criteria:**
- [ ] Music continues when app backgrounded
- [ ] Lock screen controls work
- [ ] Control Center controls work
- [ ] AirPods controls work
- [ ] CarPlay compatible (if applicable)

#### Task 4.2: iOS Background Downloads
**Estimated Time**: 12 hours
**Priority**: P1
**Dependencies**: YouTube service

**Description:**
Implement URLSession background downloads.

**Acceptance Criteria:**
- [ ] Downloads continue when app killed
- [ ] Progress updates in notification
- [ ] Downloads resume after device restart
- [ ] Handles errors gracefully
- [ ] Tests on various iOS versions

#### Task 4.3: Android Foreground Service
**Estimated Time**: 12 hours
**Priority**: P1
**Dependencies**: Audio player implementation

**Description:**
Create foreground service for music playback and downloads.

**Implementation:**
```kotlin
class MusicPlaybackService : Service() {
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "music_playback"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)

        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val playIntent = PendingIntent.getService(
            this, 0,
            Intent(this, MusicPlaybackService::class.java)
                .setAction("PLAY"),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentSong.title)
            .setContentText(currentSong.artist)
            .setSmallIcon(R.drawable.ic_music_note)
            .setLargeIcon(albumArt)
            .addAction(R.drawable.ic_play, "Play", playIntent)
            .setStyle(androidx.media.app.NotificationCompat.MediaStyle()
                .setMediaSession(mediaSession.sessionToken))
            .build()
    }
}
```

**Acceptance Criteria:**
- [ ] Persistent notification shows
- [ ] Notification controls work
- [ ] Service survives app kill
- [ ] MediaSession configured
- [ ] Battery optimization handled

---

## Risk Assessment

### Technical Risks

#### Risk 1: MediaKit Replacement Complexity
**Likelihood**: Medium
**Impact**: High
**Mitigation**:
- Start early with abstraction layer
- Use well-tested library (just_audio)
- Extensive testing on real devices
- Fallback to alternative libraries if needed

#### Risk 2: iOS Background Limitations
**Likelihood**: High
**Impact**: Medium
**Mitigation**:
- Accept limitations (downloads stop when app killed)
- Use URLSession background downloads
- Clear user communication about restrictions
- Consider push notifications for download completion

#### Risk 3: YouTube API Changes
**Likelihood**: High
**Impact**: High
**Mitigation**:
- Use backend proxy (easy to update yt-dlp)
- Implement fallback extractors
- Monitor for API changes
- Have multiple YouTube libraries ready

#### Risk 4: App Store Rejection
**Likelihood**: Medium
**Impact**: Very High
**Mitigation**:
- Remove torrent features for iOS
- Focus on streaming & user-uploaded content
- Clear ToS compliance documentation
- Legal review before submission
- Have alternative app names ready

#### Risk 5: Performance on Low-End Devices
**Likelihood**: Medium
**Impact**: Medium
**Mitigation**:
- Performance profiling early
- Optimize image loading (caching, thumbnails)
- Lazy loading for large lists
- Memory leak detection
- Test on older devices (iPhone 8, Android 8)

### Business Risks

#### Risk 6: Development Timeline Overrun
**Likelihood**: Medium
**Impact**: Medium
**Mitigation**:
- Build MVP first (streaming-only)
- Incremental releases (TestFlight first)
- Regular progress reviews
- Cut scope if needed (remove torrents)

#### Risk 7: Backend Hosting Costs
**Likelihood**: Low
**Impact**: Medium
**Mitigation**:
- Start with free tiers (Railway/Fly.io)
- Implement rate limiting
- Cache aggressively
- Consider serverless for YouTube proxy
- User-hosted backend option

#### Risk 8: Copyright/Legal Issues
**Likelihood**: Medium
**Impact**: Very High
**Mitigation**:
- Focus on legal sources (YouTube, user uploads)
- Remove torrent support if risky
- Clear DMCA compliance
- Consult legal advisor
- Have takedown process ready

---

## Timeline & Milestones

### Timeline Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                     Mobile Development Timeline                  │
├─────────────────────────────────────────────────────────────────┤
│ Weeks 1-4:   Foundation & Architecture            [████████    ]│
│ Weeks 5-8:   iOS Audio Implementation             [████████    ]│
│ Weeks 9-11:  iOS YouTube Streaming                [██████      ]│
│ Weeks 12-13: iOS File Management                  [████        ]│
│ Week 14:     iOS Beta Release                     [██          ]│
│ Weeks 15-18: Android Port                         [████████    ]│
│ Week 19:     Android Beta Release                 [██          ]│
│ Weeks 20-22: Production Polish & Launch           [██████      ]│
├─────────────────────────────────────────────────────────────────┤
│ Total: 22 weeks (5.5 months)                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Critical Milestones

**M1 - Foundation Complete (Week 4)**
- ✅ Abstraction layer in place
- ✅ Desktop still functional
- ✅ iOS/Android projects created
- **Go/No-Go Decision**: Architecture validated

**M2 - iOS Audio Works (Week 8)**
- ✅ Local file playback on iOS
- ✅ Background audio functional
- ✅ Lock screen controls working
- **Go/No-Go Decision**: Core functionality proven

**M3 - iOS Streaming Works (Week 11)**
- ✅ YouTube search and playback
- ✅ Downloads functional
- ✅ Offline mode working
- **Go/No-Go Decision**: Ready for beta testing

**M4 - iOS Beta Launch (Week 14)**
- ✅ TestFlight submission approved
- ✅ 50+ beta testers recruited
- ✅ Feedback loop established
- **Go/No-Go Decision**: Proceed with Android port

**M5 - Android Parity (Week 18)**
- ✅ All iOS features on Android
- ✅ Tested on 5+ devices
- ✅ Performance optimized
- **Go/No-Go Decision**: Ready for Android beta

**M6 - Production Launch (Week 22)**
- ✅ Both apps approved
- ✅ Marketing materials ready
- ✅ Support infrastructure in place
- **Launch!**

---

## Resource Requirements

### Development Team

**Minimum Team (Solo Developer):**
- Full-stack developer with Flutter + Swift/Kotlin experience
- Timeline: 22 weeks full-time
- Risk: High (no redundancy, single point of failure)

**Recommended Team (Small Team):**
1. **Senior Flutter Developer** (Full-time)
   - Lead mobile architecture
   - iOS implementation
   - Code reviews

2. **Flutter/Kotlin Developer** (Full-time weeks 15-18)
   - Android implementation
   - Performance optimization

3. **Backend Developer** (Part-time, 20% capacity)
   - YouTube proxy API
   - Backend deployment
   - API maintenance

4. **QA/Tester** (Part-time weeks 10-22)
   - Device testing
   - Beta management
   - Bug verification

**Optimal Team (Faster Timeline):**
- Add 1 more Flutter developer (parallel iOS + Android)
- Timeline: 14-16 weeks
- Cost: Higher, but faster to market

### Infrastructure

**Development:**
- MacBook Pro (for iOS development) - $2,500
- iPhone test device (iPhone 12 or newer) - $500
- Android test devices (2-3 devices) - $500-1,000
- Apple Developer account - $99/year
- Google Play Developer account - $25 one-time

**Backend Hosting:**
- Railway/Fly.io free tier initially
- Upgrade to paid tier: $10-50/month (depends on usage)
- Redis/cache: $10-20/month
- CDN for media: $20-50/month (if needed)

**Tools & Services:**
- Sentry (crash reporting): Free tier → $26/month
- TestFlight (iOS): Included with Apple Developer
- Firebase (analytics): Free tier → $25/month
- GitHub Actions (CI/CD): Free for public repos

**Total Initial Investment:**
- One-time: ~$4,000 (hardware + accounts)
- Monthly: ~$50-100 (hosting + services)
- Yearly: ~$1,500-2,000 (renewals + hosting)

---

## App Store Considerations

### iOS App Store

#### Guidelines Compliance

**Must Address:**
1. **Copyright Content** (Guideline 5.2)
   - Remove torrent functionality
   - Focus on legal streaming (YouTube)
   - User-uploaded content only
   - DMCA takedown process

2. **Data Collection** (Guideline 5.1.2)
   - Privacy policy required
   - Disclose data collection (analytics)
   - No selling user data
   - App Tracking Transparency framework

3. **In-App Purchase** (Guideline 3.1.1)
   - If offering premium features, must use IAP
   - Cannot bypass App Store payment
   - Clear pricing

4. **Minimum Functionality** (Guideline 4.2)
   - App must be fully functional
   - Not just a web view
   - Native iOS experience

**App Store Optimization:**
- Clear app description
- 5-10 screenshots per device size
- App preview video (recommended)
- Keywords optimization
- Localization (consider Spanish, Portuguese)

**Review Timeline:**
- First submission: 3-7 days
- Updates: 1-3 days
- Rejections: Fix and resubmit (add 3-5 days)

#### Privacy Considerations

**Required Disclosures:**
```
Data Collected:
- Identifiers (Device ID for crash reporting)
- Usage Data (Songs played, search queries)
- Diagnostics (Crash logs)

Data Not Collected:
- Contact Info
- Financial Info
- Location
- Sensitive Info

Data Linked to User: Yes (via device ID)
Data Used for Tracking: No
```

### Google Play Store

#### Guidelines Compliance

**Must Address:**
1. **Permissions** (Android manifest)
   - Request only necessary permissions
   - Runtime permission requests
   - Clear permission rationale

2. **Target API Level**
   - Must target Android 13 (API 33) or higher
   - Scoped storage compliance
   - Background restrictions compliance

3. **Content Rating**
   - IARC questionnaire required
   - Music app: Likely "Everyone" rating
   - Disclose user-generated content

4. **Copyright**
   - DMCA compliance
   - Repeat infringer policy
   - Copyright agent contact

**Play Store Optimization:**
- Feature graphic (1024x500)
- Screenshots (4-8 images)
- Promotional video (YouTube)
- Localization
- Beta testing track

**Review Timeline:**
- First submission: 2-7 days
- Updates: 1-3 days
- Faster than iOS generally

#### Required App Content

**Store Listing:**
```markdown
Title: TrustTune - AI Music Discovery
Short Description: Find and play high-quality music with AI
Full Description:
TrustTune makes music discovery simple with AI-powered search.
Ask for music naturally ("radiohead ok computer") and get instant
results from YouTube and your local library.

Features:
- Natural language music search
- YouTube streaming & downloads
- Offline playback
- High-quality audio
- Clean, minimal interface

Privacy: We don't sell your data. Open source and community-driven.
```

---

## Decision Framework

### Should You Pursue Mobile?

**YES, if:**
- ✅ You want to reach mobile-first audience
- ✅ You can dedicate 3-6 months of development time
- ✅ You're willing to remove torrent support (iOS)
- ✅ You have budget for development & hosting ($5K-10K)
- ✅ You're comfortable with app store review processes
- ✅ You can commit to ongoing maintenance

**NO (or wait), if:**
- ❌ Desktop app isn't stable yet
- ❌ You don't have mobile development experience
- ❌ Torrents are core to your value proposition
- ❌ You can't dedicate sustained development time
- ❌ Budget is very limited (<$2K)
- ❌ You prefer to focus on desktop features

### Which Platform First?

**Start with iOS if:**
- Target audience has iPhones
- Premium/paid app model planned
- You want clearer API guidelines
- You're okay with more restrictions

**Start with Android if:**
- Want more technical flexibility
- Background downloads are critical
- Target global/budget-conscious users
- Want faster iteration cycles

**Recommendation: iOS first**
- Prove concept with stricter platform
- If iOS works, Android is easier
- iOS users more likely to pay
- Better for initial traction

### Feature Scope Decision Tree

```
┌─────────────────────────────────────────────┐
│ Do you NEED torrents on mobile?             │
└─────────┬───────────────────────┬───────────┘
          │                       │
          NO                      YES
          │                       │
    ┌─────▼──────┐         ┌─────▼──────────┐
    │ Stream-only│         │ Android-only   │
    │  approach  │         │   or Cloud     │
    │            │         │     Proxy      │
    │ ✅ Simpler │         │                │
    │ ✅ Faster  │         │ ⚠️ Complex     │
    │ ✅ iOS OK  │         │ ⚠️ Slower      │
    │            │         │ ❌ No iOS      │
    └────────────┘         └────────────────┘
         │                        │
         │                        │
    12-14 weeks              18-22 weeks
```

**Recommendation:** Start with streaming-only MVP. Add torrents later if there's demand and you can solve the iOS limitation (cloud proxy).

---

## Conclusion

### Executive Summary

**Mobile distribution for TrustTune is FEASIBLE and RECOMMENDED.**

**Key Points:**
1. **Effort**: 12-22 weeks depending on scope
2. **Cost**: $5K-10K initial investment
3. **Architecture**: Requires significant refactoring but well-planned
4. **Platforms**: iOS first (14 weeks), Android second (+4-6 weeks)
5. **Features**: Streaming works great, torrents problematic on iOS
6. **Timeline**: 5.5 months to production on both platforms

**Critical Success Factors:**
- ✅ Start with abstraction layer (weeks 1-4)
- ✅ Replace MediaKit with just_audio (proven library)
- ✅ Backend proxy for YouTube (easier maintenance)
- ✅ Stream-only MVP (remove torrents initially)
- ✅ Incremental releases (TestFlight → beta → production)

**Recommended Approach:**

**Phase 1: iOS Streaming MVP (14 weeks)**
- Audio playback ✅
- YouTube streaming ✅
- Local library ✅
- Background audio ✅
- Downloads ✅

**Phase 2: Android Port (4-6 weeks)**
- Port iOS implementation
- Platform-specific optimizations
- Beta testing

**Phase 3: Production Launch (2-3 weeks)**
- Bug fixes from beta
- App Store submissions
- Marketing & launch

**Phase 4: Future Enhancements (optional)**
- Cloud torrent proxy for high-quality downloads
- Social features (sharing, playlists)
- Advanced audio features (equalizer, crossfade)
- Tablet-optimized layouts

### Next Steps

**Immediate Actions (Week 1):**
1. ✅ Review this roadmap with stakeholders
2. ✅ Decide on feature scope (streaming vs torrents)
3. ✅ Secure development resources (team/budget)
4. ✅ Set up iOS/Android development environments
5. ✅ Create GitHub project board for task tracking
6. ✅ Begin abstraction layer implementation

**This Week (Week 1-2):**
1. Create AudioPlayerInterface
2. Wrap MediaKit in abstraction
3. Set up iOS project structure
4. Configure CI/CD for multi-platform builds
5. Deploy backend to cloud (for testing)

**This Month (Weeks 1-4):**
1. Complete foundation phase
2. Validate architecture with desktop builds
3. Begin iOS audio implementation
4. Test on physical iOS device
5. Conduct go/no-go review for Phase 2

### Questions to Answer Before Starting

1. **Feature Scope**: Streaming-only or include torrents?
2. **Platform Priority**: iOS first or Android first?
3. **Timeline**: Rush (12 weeks) or comfortable (22 weeks)?
4. **Team Size**: Solo or small team?
5. **Budget**: $5K or $10K+?
6. **Backend Hosting**: Self-hosted or cloud?
7. **Monetization**: Free, paid, or freemium?

### Success Metrics

**Technical:**
- ✅ Audio playback works on iOS/Android
- ✅ <5% crash rate
- ✅ App launches in <2 seconds
- ✅ <10MB download size
- ✅ 4.0+ star rating

**Business:**
- ✅ 1,000 downloads in first month
- ✅ 30% Week 1 retention
- ✅ 100+ active beta testers
- ✅ <5 critical bugs in production

**User Experience:**
- ✅ Can find and play music in <30 seconds
- ✅ Background playback works reliably
- ✅ Intuitive UI (no tutorial needed)
- ✅ Offline mode functional

---

## Appendix

### A. Recommended Libraries

**Audio Playback:**
- just_audio (^0.9.36) - Best cross-platform audio player
- audio_service (^0.18.12) - Background audio + notifications
- audio_session (^0.1.18) - iOS/Android audio session management

**Alternative if just_audio has issues:**
- audioplayers (^5.2.1) - Simpler but less features

**File Management:**
- file_picker (^8.1.4) - Already using, has mobile support
- path_provider (^2.1.5) - Already using, has mobile support
- permission_handler (^11.3.0) - Runtime permissions

**UI/UX:**
- cached_network_image (^3.3.1) - Image caching
- shimmer (^3.0.0) - Loading skeletons
- flutter_slidable (^3.1.1) - Already using
- lottie (^3.1.0) - Animations (optional)

**Backend:**
- http (^1.2.1) - Already using
- web_socket_channel (^3.0.1) - Already using
- dio (^5.4.0) - Alternative HTTP client with better features

**Storage:**
- sqflite (^2.3.2) - SQLite for mobile
- hive (^2.2.3) - Alternative NoSQL storage
- drift (^2.16.0) - Type-safe SQLite (advanced)

**Utilities:**
- connectivity_plus (^5.0.2) - Network connectivity detection
- battery_plus (^5.0.2) - Battery status
- device_info_plus (^10.1.0) - Device information

### B. Reference Projects

**Open Source Music Apps (for inspiration):**

1. **BlackHole** (Flutter)
   - GitHub: Sangwan5688/BlackHole
   - Features: YouTube Music, local playback, lyrics
   - Platform: Android, iOS
   - Learnings: Background service, YouTube extraction

2. **Spotube** (Flutter)
   - GitHub: KRTirtho/spotube
   - Features: Spotify client with YouTube audio
   - Platform: Desktop + Android
   - Learnings: Audio player abstraction

3. **ViMusic** (Jetpack Compose - Android only)
   - GitHub: vfsfitvnm/ViMusic
   - Features: YouTube Music client
   - Platform: Android
   - Learnings: YouTube integration, cache strategy

4. **Namida** (Flutter)
   - GitHub: namidaco/namida
   - Features: Local + YouTube, advanced audio
   - Platform: Android
   - Learnings: Performance optimization

### C. Testing Checklist

**iOS Testing:**
- [ ] iPhone 8 (oldest supported)
- [ ] iPhone 12 Pro (mid-range)
- [ ] iPhone 15 Pro Max (latest)
- [ ] iPad (tablet layout)
- [ ] iOS 14, 15, 16, 17
- [ ] Dark mode
- [ ] Low power mode
- [ ] Background app refresh off
- [ ] Airplane mode (offline)
- [ ] Bluetooth devices
- [ ] CarPlay (if applicable)

**Android Testing:**
- [ ] Android 10 (Pixel 3)
- [ ] Android 11 (Samsung)
- [ ] Android 12 (Pixel 5)
- [ ] Android 13 (Pixel 6)
- [ ] Android 14 (Pixel 7)
- [ ] Tablet (10" screen)
- [ ] Various screen sizes (5", 6", 7")
- [ ] Battery saver mode
- [ ] Restricted background mode
- [ ] Different manufacturers (Samsung, Xiaomi, OnePlus)

### D. Useful Resources

**Documentation:**
- Flutter: https://flutter.dev/docs
- just_audio: https://pub.dev/packages/just_audio
- Apple Developer: https://developer.apple.com
- Android Developer: https://developer.android.com

**Communities:**
- r/FlutterDev - Reddit community
- Flutter Discord - Real-time help
- Stack Overflow - Technical Q&A

**Courses (if needed):**
- Flutter & Dart - The Complete Guide (Udemy)
- iOS & Swift - The Complete iOS App Development (Udemy)
- Android Kotlin Developer (Google)

---

**Document End**

*This roadmap is a living document and should be updated as the project progresses. Review and adjust timelines based on actual progress.*
