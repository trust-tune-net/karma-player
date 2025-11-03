# KarmaPlayer Mobile - MVP Development Plan

**Version**: 1.0
**Date**: November 2025
**Status**: Planning Phase
**Approach**: Keep It Simple Stupid (KISS)

---

## Executive Summary

**Goal**: Create a mobile companion app that lets users stream their desktop music library, discover music through friends, and enjoy high-quality playback with detailed statistics.

**Core Philosophy**:
- Desktop does the heavy lifting (library management, downloads, processing)
- Mobile extends reach (stream, browse, share, discover)
- Friends-first discovery (leverage existing social connections)
- Statistics obsession (users LOVE their data)

**Timeline**: 12-14 weeks to functional MVP
**Platforms**: iOS first, Android follow (same codebase)

---

## Table of Contents
1. [MVP Feature Set](#mvp-feature-set)
2. [Technical Architecture](#technical-architecture)
3. [Development Phases](#development-phases)
4. [Detailed Task Breakdown](#detailed-task-breakdown)
5. [Desktop Integration Requirements](#desktop-integration-requirements)
6. [Data Models](#data-models)
7. [API Specifications](#api-specifications)
8. [Risk Mitigation](#risk-mitigation)

---

## MVP Feature Set

### ✅ Phase 1: Core Streaming (Weeks 1-4)
**Must-Have - No App Without These**

1. **Desktop Discovery & Connection**
   - Auto-discover desktop on local network (mDNS/Bonjour)
   - Manual connection via IP address
   - Connection status indicator
   - Reconnection on network changes

2. **Library Browsing**
   - View all artists, albums, tracks
   - Album art display
   - Sort by: name, date added, recently played
   - Basic filtering

3. **Music Streaming**
   - Stream from desktop to mobile
   - Adaptive quality (WiFi: lossless, Cellular: compressed)
   - Buffering with progress indicator
   - Gapless playback

4. **Playback Controls**
   - Play, pause, skip, previous
   - Progress bar with scrubbing
   - Volume control
   - Queue management (add, remove, reorder)

5. **Now Playing Screen**
   - Full-screen album art
   - Track metadata (artist, album, year)
   - Audio format badge (FLAC, MP3, etc.)
   - Bitrate & sample rate display

### ⭐ Phase 2: Social Discovery (Weeks 5-8)
**High Value - What Makes This Special**

6. **User Statistics Dashboard** 🔥
   - Total listening time (today, week, month, all-time)
   - Top artists (by play count, listening time)
   - Top albums & tracks
   - Listening patterns (time of day heatmap)
   - Genre distribution pie chart
   - Format breakdown (% FLAC vs MP3 vs AAC)
   - Quality score (average bitrate of listened tracks)
   - Listening streaks (consecutive days)
   - "You've listened to 127 albums this month" insights

7. **Friend Library Matching** 🔥
   - Add friends (via code, QR, or link)
   - Calculate library overlap percentage
   - "You and João have 67% taste match"
   - Show shared artists/albums
   - Highlight unique albums (what they have that you don't)
   - Compatibility score based on listening patterns

8. **Browse Friend Libraries**
   - View friend's complete library (with permission)
   - See what friends are listening to (live)
   - See friend's top tracks/albums
   - Filter: "Albums João has but I don't"
   - Request track/album (notify friend)

9. **Quick Share** 🔥
   - Send track/album to friend instantly
   - Friend gets notification → can stream or download
   - Share via link (opens in app if installed)
   - Copy metadata (for finding elsewhere)
   - "Recommend" action (with optional note)

### 🎨 Phase 3: Audiophile Features (Weeks 9-11)
**Polish - What Audiophiles Expect**

10. **Format Info Display**
    - Badge on each track (FLAC/MP3/AAC/ALAC)
    - Bitrate visible in list view
    - Sample rate & bit depth (44.1kHz 16-bit, 96kHz 24-bit)
    - File size
    - Codec details
    - Filter library by format ("Show only FLAC")
    - "Quality warnings" for low bitrate files

11. **Equalizer & Audio Settings**
    - 10-band parametric EQ
    - Presets: Flat, Rock, Jazz, Classical, Podcast, Custom
    - Per-headphone EQ profiles (save different settings)
    - Crossfeed toggle (improve headphone imaging)
    - ReplayGain support
    - Gapless playback toggle
    - Audio output device selection (Bluetooth, wired)

### 🔧 Phase 4: Essential Features (Weeks 12-14)
**Table Stakes - Expected Functionality**

12. **Search**
    - Search by artist, album, track
    - Recent searches
    - Search filters (format, year, genre)

13. **Playlists**
    - View desktop playlists
    - Create mobile playlists
    - Add/remove tracks
    - Reorder tracks (drag & drop)
    - Sync with desktop
    - Smart playlists (auto-update based on rules)

14. **Offline Cache**
    - Mark albums/tracks "Available Offline"
    - Auto-download on WiFi
    - Storage management (set cache size limit)
    - Clear cache option
    - Prefer cached when available

15. **Remote Control Desktop Playback**
    - See what's playing on desktop
    - Control desktop player from mobile
    - Handoff (pause on desktop, resume on mobile)
    - Desktop queue visibility

16. **Settings & Preferences**
    - Streaming quality: Auto, High (lossless), Medium (320kbps), Low (128kbps)
    - Download quality
    - Cellular data usage (warn/block streaming on cellular)
    - Storage location
    - Theme (light/dark/auto)
    - Desktop connection settings

---

## Technical Architecture

### Technology Stack

**Frontend (Mobile)**
```yaml
Framework: Flutter 3.24+
Language: Dart 3.9+
State Management: Riverpod 2.5+
Audio Player: just_audio ^0.9.40
HTTP Client: dio ^5.4.0
WebSocket: web_socket_channel ^3.0.0
Local DB: drift (SQLite) ^2.18.0
Network Discovery: multicast_dns ^0.3.2
Charts: fl_chart ^0.68.0
```

**Backend (Desktop Side)**
```yaml
Server: FastAPI (Python) or Dart Shelf
Protocol: HTTP/2 + WebSocket
Discovery: mDNS (Avahi/Bonjour)
Streaming: Chunked transfer encoding
Auth: JWT tokens
```

**Communication Protocol**
- **Discovery**: mDNS/Bonjour (local network auto-discovery)
- **API**: REST (HTTP/2) for library browsing, metadata
- **Streaming**: HTTP range requests for adaptive streaming
- **Real-time**: WebSocket for now playing, friend activity
- **Sync**: SQLite replication for offline data

### Architecture Diagram

```
┌─────────────────────────────────────────┐
│          Mobile App (Flutter)            │
├─────────────────────────────────────────┤
│  UI Layer                                │
│    ├─ Screens (Home, Library, Stats)    │
│    ├─ Widgets (TrackList, NowPlaying)   │
│    └─ Theme                              │
├─────────────────────────────────────────┤
│  State Management (Riverpod)             │
│    ├─ Providers (library, playback)     │
│    ├─ Notifiers (state logic)           │
│    └─ Controllers (business logic)      │
├─────────────────────────────────────────┤
│  Services Layer                          │
│    ├─ Desktop Connection Service        │
│    ├─ Audio Player Service              │
│    ├─ Statistics Service                │
│    ├─ Friend Service                    │
│    └─ Cache Service                     │
├─────────────────────────────────────────┤
│  Data Layer                              │
│    ├─ Local Database (Drift/SQLite)     │
│    ├─ API Client (REST)                 │
│    ├─ WebSocket Client                  │
│    └─ File Storage                      │
└─────────────────────────────────────────┘
              ↕ Network
┌─────────────────────────────────────────┐
│      Desktop App (Existing)              │
├─────────────────────────────────────────┤
│  NEW: Mobile API Server                  │
│    ├─ REST Endpoints (/api/v1/...)      │
│    ├─ WebSocket Server                  │
│    ├─ mDNS Publisher                    │
│    └─ Audio Streaming Engine            │
├─────────────────────────────────────────┤
│  Existing: Library Management            │
│  Existing: Playback Engine               │
│  Existing: Download Manager              │
└─────────────────────────────────────────┘
```

### Data Flow

**Library Browsing**
```
Mobile → Desktop: GET /api/v1/library/artists
Desktop → Mobile: JSON { artists: [...] }
Mobile: Store in local DB → Display
```

**Music Streaming**
```
Mobile → Desktop: GET /api/v1/stream/{trackId}?quality=high
Desktop: Check file → Stream chunks
Mobile: Buffer → Decode → Play (just_audio)
```

**Statistics**
```
Mobile: Track playback events locally
Mobile → Desktop: POST /api/v1/stats/sync (batch every 5 min)
Desktop: Aggregate stats
Desktop → Mobile: GET /api/v1/stats/summary
```

**Friend Matching**
```
User A Mobile → Desktop A: GET /api/v1/library/fingerprint
User A Mobile: Share fingerprint with User B (QR/link)
User B Mobile: Compare fingerprints locally
User B Mobile: Calculate overlap %
```

---

## Development Phases

### Phase 1: Foundation (Weeks 1-4)

**Week 1: Project Setup & Desktop Integration**
- [ ] Flutter project structure (feature-first architecture)
- [ ] Riverpod state management setup
- [ ] Desktop API server basics (FastAPI or Dart Shelf)
- [ ] mDNS discovery implementation (desktop broadcasts, mobile discovers)
- [ ] Basic REST API (GET /library/artists, /library/albums)
- [ ] Mobile HTTP client with error handling
- [ ] Connection management (connect, disconnect, status)

**Week 2: Library Browsing**
- [ ] Local database schema (Drift)
- [ ] Sync library metadata from desktop
- [ ] Artists list screen
- [ ] Albums list screen (with album art)
- [ ] Track list screen
- [ ] Search functionality (local filtering first)
- [ ] Loading states & error handling

**Week 3: Audio Streaming**
- [ ] Desktop audio streaming endpoint (HTTP range requests)
- [ ] Mobile audio player service (just_audio integration)
- [ ] Adaptive quality selection (detect network type)
- [ ] Buffering logic
- [ ] Playback state management (Riverpod provider)
- [ ] Now playing notification (lock screen controls)

**Week 4: Playback UI**
- [ ] Now playing screen (full-screen album art)
- [ ] Playback controls (play, pause, skip)
- [ ] Progress bar with scrubbing
- [ ] Queue screen (add, remove, reorder)
- [ ] Mini player (persistent bottom bar)
- [ ] Format badge display (FLAC/MP3/etc.)

**Deliverable**: Can discover desktop, browse library, stream music

---

### Phase 2: Social Features (Weeks 5-8)

**Week 5: Statistics Infrastructure**
- [ ] Playback event tracking (start, pause, skip, complete)
- [ ] Local stats database schema
- [ ] Stats aggregation logic (daily, weekly, monthly)
- [ ] Top artists/albums calculation
- [ ] Listening patterns analysis
- [ ] Sync stats to desktop (batch upload)

**Week 6: Statistics Dashboard**
- [ ] Stats home screen design
- [ ] Charts integration (fl_chart)
- [ ] Listening time widgets (today, week, month)
- [ ] Top artists/albums lists
- [ ] Listening patterns heatmap
- [ ] Genre distribution pie chart
- [ ] Format breakdown
- [ ] Insights generation ("You've listened to...")

**Week 7: Friend System**
- [ ] User account system (simple JWT auth)
- [ ] Add friend flow (via code, QR, link)
- [ ] Library fingerprint generation (efficient matching algorithm)
- [ ] Friend list screen
- [ ] Library overlap calculation
- [ ] Compatibility score algorithm
- [ ] Shared/unique albums lists

**Week 8: Friend Library Browsing & Sharing**
- [ ] Browse friend library (permission-based)
- [ ] Live friend activity (WebSocket)
- [ ] Friend stats comparison
- [ ] Quick share implementation (send track/album)
- [ ] In-app notifications for shares
- [ ] Deep linking (open shared tracks in app)

**Deliverable**: Users can track stats, add friends, see taste overlap, share music

---

### Phase 3: Audiophile Features (Weeks 9-11)

**Week 9: Format Info Display**
- [ ] Audio format detection (from metadata)
- [ ] Format badges on track lists
- [ ] Detailed audio info screen
- [ ] Filter by format
- [ ] Quality warnings (low bitrate detection)
- [ ] Format distribution in stats

**Week 10: Equalizer**
- [ ] EQ UI (10-band sliders)
- [ ] Preset system (save/load)
- [ ] Apply EQ to audio player
- [ ] Per-device EQ profiles
- [ ] Crossfeed implementation
- [ ] ReplayGain support

**Week 11: Audio Settings & Polish**
- [ ] Audio output device selection
- [ ] Gapless playback toggle
- [ ] Advanced audio settings screen
- [ ] Audio quality testing tools
- [ ] Performance optimization
- [ ] Bug fixes

**Deliverable**: Audiophile-grade features complete

---

### Phase 4: Essential Features (Weeks 12-14)

**Week 12: Playlists & Search**
- [ ] Desktop playlist sync
- [ ] Create/edit playlists
- [ ] Smart playlists (auto-update)
- [ ] Advanced search (filters)
- [ ] Search history
- [ ] Search suggestions

**Week 13: Offline & Remote Control**
- [ ] Offline cache implementation
- [ ] Download manager (queue, progress)
- [ ] Storage management
- [ ] Remote control desktop playback
- [ ] Handoff between devices
- [ ] Desktop queue visibility

**Week 14: Settings & Final Polish**
- [ ] Comprehensive settings screen
- [ ] Streaming quality options
- [ ] Theme selection (light/dark)
- [ ] About screen (version, licenses)
- [ ] Onboarding tutorial
- [ ] Final bug fixes & testing
- [ ] iOS TestFlight build
- [ ] Android beta build

**Deliverable**: Feature-complete MVP ready for beta testing

---

## Detailed Task Breakdown

### Desktop Integration Tasks

**Desktop API Server (New Component)**

```python
# FastAPI example structure
from fastapi import FastAPI, WebSocket
from fastapi.responses import StreamingResponse

app = FastAPI()

# Library endpoints
@app.get("/api/v1/library/artists")
async def get_artists():
    # Query local database
    # Return: [{ id, name, album_count, track_count }]
    pass

@app.get("/api/v1/library/albums")
async def get_albums(artist_id: Optional[int] = None):
    # Return: [{ id, title, artist, year, art_url, track_count }]
    pass

@app.get("/api/v1/library/tracks")
async def get_tracks(album_id: Optional[int] = None):
    # Return: [{ id, title, artist, album, duration, format, bitrate }]
    pass

# Streaming endpoint
@app.get("/api/v1/stream/{track_id}")
async def stream_track(track_id: int, quality: str = "high"):
    # Get file path from database
    # Transcode if needed based on quality
    # Return: StreamingResponse with audio chunks
    pass

# WebSocket for real-time updates
@app.websocket("/api/v1/ws")
async def websocket_endpoint(websocket: WebSocket):
    # Handle real-time events: now_playing, friend_activity
    pass
```

**mDNS Discovery (Desktop)**
```python
from zeroconf import ServiceInfo, Zeroconf

# Broadcast desktop service
def advertise_service():
    info = ServiceInfo(
        "_karmaplayer._tcp.local.",
        "KarmaPlayer Desktop._karmaplayer._tcp.local.",
        addresses=[get_local_ip()],
        port=8080,
        properties={'version': '1.0', 'api': 'v1'}
    )
    zeroconf = Zeroconf()
    zeroconf.register_service(info)
```

**Desktop Changes Needed**
1. Add API server module (FastAPI or Shelf)
2. Add mDNS service broadcaster
3. Add audio streaming endpoint (with transcoding)
4. Add WebSocket server for real-time events
5. Add stats sync endpoint (receive mobile stats)
6. Add friend system (store friend connections)

**Estimated Desktop Work**: 3-4 weeks parallel to mobile development

---

### Mobile Implementation Details

#### Folder Structure
```
lib/
├── main.dart
├── app.dart (MaterialApp setup)
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   └── extensions/
├── features/
│   ├── connection/
│   │   ├── data/ (repositories, data sources)
│   │   ├── domain/ (models, use cases)
│   │   └── presentation/ (screens, widgets, providers)
│   ├── library/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── playback/
│   ├── stats/
│   ├── friends/
│   ├── settings/
│   └── ...
├── shared/
│   ├── widgets/ (reusable components)
│   ├── models/
│   └── services/
└── infrastructure/
    ├── database/
    ├── network/
    └── storage/
```

#### Key Data Models

```dart
// Track model
class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration; // seconds
  final AudioFormat format;
  final int bitrate;
  final int sampleRate;
  final String artUrl;
  final DateTime dateAdded;
}

// AudioFormat enum
enum AudioFormat {
  flac, alac, wav,  // Lossless
  mp3, aac, opus,   // Lossy
  dsd, mqa          // Hi-res
}

// Playback state
class PlaybackState {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<Track> queue;
  final RepeatMode repeatMode;
  final bool shuffleEnabled;
}

// User statistics
class UserStats {
  final Duration totalListeningTime;
  final Map<String, int> topArtists; // artist -> play count
  final Map<String, Duration> artistListeningTime;
  final Map<AudioFormat, int> formatBreakdown;
  final List<ListeningSession> recentSessions;
  final int listeningStreak; // consecutive days
}

// Friend connection
class Friend {
  final String id;
  final String name;
  final String avatarUrl;
  final double tasteMatchPercentage;
  final LibraryFingerprint fingerprint;
  final DateTime lastActive;
}

// Library fingerprint (for matching)
class LibraryFingerprint {
  final Set<String> artistIds;
  final Set<String> albumIds;
  final Map<String, int> genreCounts;
  final int totalTracks;
}
```

#### Core Services

**Desktop Connection Service**
```dart
class DesktopConnectionService {
  // mDNS discovery
  Future<List<DesktopInstance>> discoverDesktops();

  // Connect to desktop
  Future<void> connect(DesktopInstance desktop);

  // Connection status stream
  Stream<ConnectionStatus> get connectionStatus;

  // Reconnect on network changes
  Future<void> reconnect();
}
```

**Audio Player Service**
```dart
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  // Play track (stream from desktop)
  Future<void> play(Track track, {AudioQuality quality});

  // Playback controls
  Future<void> pause();
  Future<void> resume();
  Future<void> skipNext();
  Future<void> skipPrevious();
  Future<void> seek(Duration position);

  // Queue management
  Future<void> addToQueue(Track track);
  Future<void> setQueue(List<Track> tracks);

  // Playback state stream
  Stream<PlaybackState> get playbackState;
}
```

**Statistics Service**
```dart
class StatisticsService {
  // Track playback event
  void recordPlayback(Track track, Duration duration);

  // Get aggregated stats
  Future<UserStats> getStats({
    DateTime? startDate,
    DateTime? endDate,
  });

  // Sync stats to desktop
  Future<void> syncToDesktop();

  // Get insights
  List<Insight> generateInsights(UserStats stats);
}
```

**Friend Service**
```dart
class FriendService {
  // Add friend
  Future<void> addFriend(String friendCode);

  // Get friends list
  Future<List<Friend>> getFriends();

  // Calculate library match
  Future<double> calculateMatch(Friend friend);

  // Get shared/unique albums
  Future<LibraryComparison> compareLibraries(Friend friend);

  // Browse friend's library
  Future<List<Track>> getFriendLibrary(Friend friend);

  // Share track/album
  Future<void> share(Track track, Friend friend);
}
```

---

## Desktop Integration Requirements

### New Desktop Components Needed

1. **Mobile API Server Module**
   - FastAPI or Dart Shelf server
   - Port: 8080 (configurable)
   - HTTPS support (self-signed cert for local network)
   - CORS enabled for mobile app

2. **Service Discovery**
   - mDNS/Bonjour broadcaster
   - Service name: `_karmaplayer._tcp.local.`
   - Includes: IP, port, version, capabilities

3. **Audio Streaming Engine**
   - HTTP range request support
   - On-the-fly transcoding (FLAC → AAC for cellular)
   - Quality presets: original, high (320kbps), medium (192kbps), low (128kbps)
   - Chunked transfer encoding

4. **WebSocket Server**
   - Real-time now playing updates
   - Friend activity notifications
   - Sync events

5. **Stats Aggregation**
   - Receive playback events from mobile
   - Merge with desktop listening stats
   - Generate unified insights

6. **Friend System Backend**
   - Store friend connections
   - Generate library fingerprints
   - Calculate compatibility scores

### Desktop API Endpoints Specification

See [API Specifications](#api-specifications) section below.

---

## API Specifications

### REST API Endpoints

**Base URL**: `http://{desktop-ip}:8080/api/v1`

#### Discovery & Connection

```
GET /ping
Response: { status: "ok", version: "1.0", desktop_name: "John's MacBook" }
```

```
POST /auth/connect
Body: { device_id: "...", device_name: "iPhone 14" }
Response: { token: "jwt_token", expires_at: "..." }
```

#### Library

```
GET /library/artists?offset=0&limit=100
Response: {
  artists: [
    { id: "1", name: "Radiohead", album_count: 12, track_count: 156 }
  ],
  total: 423
}
```

```
GET /library/albums?artist_id=1&offset=0&limit=50
Response: {
  albums: [
    {
      id: "101",
      title: "OK Computer",
      artist: "Radiohead",
      year: 1997,
      art_url: "/api/v1/art/101",
      track_count: 12,
      duration: 3214  // seconds
    }
  ]
}
```

```
GET /library/tracks?album_id=101
Response: {
  tracks: [
    {
      id: "1001",
      title: "Airbag",
      artist: "Radiohead",
      album: "OK Computer",
      track_number: 1,
      duration: 284,
      format: "flac",
      bitrate: 1411,
      sample_rate: 44100,
      bit_depth: 16,
      file_size: 51234567
    }
  ]
}
```

```
GET /library/search?q=paranoid&type=all
Response: {
  artists: [...],
  albums: [...],
  tracks: [...]
}
```

#### Streaming

```
GET /stream/{track_id}?quality=high
Headers: Range: bytes=0-
Response:
  - Content-Type: audio/mpeg (or audio/flac)
  - Content-Length: 51234567
  - Accept-Ranges: bytes
  - Body: audio stream
```

#### Playlists

```
GET /playlists
Response: {
  playlists: [
    { id: "1", name: "Favorites", track_count: 47, duration: 8934 }
  ]
}
```

```
GET /playlists/{id}/tracks
Response: { tracks: [...] }
```

```
POST /playlists
Body: { name: "My Playlist", track_ids: ["1001", "1002"] }
Response: { id: "2", ... }
```

#### Statistics

```
POST /stats/sync
Body: {
  events: [
    {
      track_id: "1001",
      started_at: "2025-11-03T10:30:00Z",
      duration: 284,
      completed: true
    }
  ]
}
Response: { synced: 15 }
```

```
GET /stats/summary?period=month
Response: {
  total_listening_time: 86400,  // seconds
  top_artists: [
    { artist: "Radiohead", play_count: 47, listening_time: 12453 }
  ],
  format_breakdown: {
    "flac": 67,
    "mp3": 23,
    "aac": 10
  }
}
```

#### Friends

```
POST /friends/fingerprint
Response: {
  fingerprint: "base64_encoded_data",
  artist_count: 234,
  album_count: 567,
  track_count: 8901
}
```

```
POST /friends/match
Body: { friend_fingerprint: "base64_..." }
Response: {
  match_percentage: 67.5,
  shared_artists: 156,
  shared_albums: 234,
  unique_to_me: 78,
  unique_to_them: 123
}
```

```
GET /friends/{friend_id}/library/albums?offset=0&limit=50
Response: { albums: [...] }
```

```
POST /friends/share
Body: {
  friend_id: "friend_123",
  track_id: "1001",
  message: "Check this out!"
}
Response: { shared: true, notification_sent: true }
```

#### Settings

```
GET /settings
Response: {
  desktop_name: "John's MacBook",
  library_path: "/Users/john/Music",
  track_count: 8901,
  total_size: 234567890123
}
```

### WebSocket Protocol

**Connection**: `ws://{desktop-ip}:8080/api/v1/ws?token={jwt_token}`

**Message Format**: JSON

**Events from Desktop → Mobile**

```json
// Now playing on desktop
{
  "type": "desktop_now_playing",
  "track": { "id": "1001", "title": "...", ... },
  "position": 45,
  "is_playing": true
}

// Friend activity
{
  "type": "friend_activity",
  "friend_id": "friend_123",
  "activity": "listening",
  "track": { ... }
}

// Share received
{
  "type": "share_received",
  "from_friend": "friend_123",
  "track": { ... },
  "message": "Check this out!"
}

// Library updated
{
  "type": "library_updated",
  "added_tracks": 23,
  "updated_tracks": 5
}
```

**Events from Mobile → Desktop**

```json
// Mobile now playing (for stats)
{
  "type": "mobile_now_playing",
  "track_id": "1001",
  "position": 45,
  "is_playing": true
}

// Remote control desktop
{
  "type": "desktop_control",
  "action": "play" | "pause" | "skip_next" | "skip_previous"
}
```

---

## Data Models

### Database Schema (Mobile - SQLite via Drift)

```sql
-- Desktop connections
CREATE TABLE desktops (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  ip_address TEXT NOT NULL,
  port INTEGER NOT NULL,
  last_connected_at INTEGER,
  is_default INTEGER DEFAULT 0
);

-- Cached library metadata
CREATE TABLE artists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  album_count INTEGER,
  track_count INTEGER,
  synced_at INTEGER
);

CREATE TABLE albums (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist_id TEXT,
  artist_name TEXT,
  year INTEGER,
  art_url TEXT,
  track_count INTEGER,
  duration INTEGER,
  synced_at INTEGER,
  FOREIGN KEY (artist_id) REFERENCES artists(id)
);

CREATE TABLE tracks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist_id TEXT,
  artist_name TEXT,
  album_id TEXT,
  album_name TEXT,
  track_number INTEGER,
  duration INTEGER,
  format TEXT,
  bitrate INTEGER,
  sample_rate INTEGER,
  bit_depth INTEGER,
  file_size INTEGER,
  art_url TEXT,
  synced_at INTEGER,
  FOREIGN KEY (album_id) REFERENCES albums(id)
);

-- Playback history (for statistics)
CREATE TABLE playback_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  track_id TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER,
  duration INTEGER,
  completed INTEGER DEFAULT 0,
  synced_to_desktop INTEGER DEFAULT 0,
  FOREIGN KEY (track_id) REFERENCES tracks(id)
);

-- Playlists
CREATE TABLE playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at INTEGER,
  is_smart INTEGER DEFAULT 0,
  smart_rules TEXT  -- JSON
);

CREATE TABLE playlist_tracks (
  playlist_id TEXT,
  track_id TEXT,
  position INTEGER,
  added_at INTEGER,
  PRIMARY KEY (playlist_id, track_id),
  FOREIGN KEY (playlist_id) REFERENCES playlists(id),
  FOREIGN KEY (track_id) REFERENCES tracks(id)
);

-- Friends
CREATE TABLE friends (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  avatar_url TEXT,
  fingerprint TEXT,  -- base64 encoded
  taste_match_percentage REAL,
  added_at INTEGER,
  last_active_at INTEGER
);

-- Offline cache
CREATE TABLE cached_tracks (
  track_id TEXT PRIMARY KEY,
  file_path TEXT NOT NULL,
  file_size INTEGER,
  quality TEXT,
  downloaded_at INTEGER,
  last_accessed_at INTEGER,
  FOREIGN KEY (track_id) REFERENCES tracks(id)
);

-- Settings/preferences
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT
);
```

### Indexes

```sql
CREATE INDEX idx_albums_artist ON albums(artist_id);
CREATE INDEX idx_tracks_album ON tracks(album_id);
CREATE INDEX idx_tracks_artist ON tracks(artist_id);
CREATE INDEX idx_playback_started ON playback_events(started_at);
CREATE INDEX idx_playback_track ON playback_events(track_id);
```

---

## Risk Mitigation

### Technical Risks

**Risk**: Desktop-mobile connection unreliable on some networks
**Mitigation**:
- Manual IP entry fallback
- Connection retry logic with exponential backoff
- Store last successful connection for quick reconnect
- Support both WiFi and mobile hotspot scenarios

**Risk**: Audio streaming stutters on poor connections
**Mitigation**:
- Adaptive bitrate streaming (detect network speed)
- Large buffer (30 seconds ahead)
- Prefetch next track in queue
- Cache aggressively on WiFi
- Show network quality indicator

**Risk**: Battery drain from constant streaming
**Mitigation**:
- Efficient background processing
- WiFi-only mode for downloads
- Power-saving mode (reduces visualizations)
- Background playback optimization

**Risk**: Storage issues (offline cache fills device)
**Mitigation**:
- User-configurable cache size limit
- Auto-evict least recently played
- Show storage usage in settings
- Warn when low on space

### UX Risks

**Risk**: Users don't understand desktop-mobile relationship
**Mitigation**:
- Clear onboarding flow
- Visual connection status indicator
- Helpful error messages
- Tutorial screens

**Risk**: Friend system privacy concerns
**Mitigation**:
- Opt-in for library sharing
- Granular privacy controls
- Clear indicators when library is visible
- Easy friend removal

**Risk**: Statistics feel invasive
**Mitigation**:
- All stats stored locally by default
- Option to disable tracking
- Clear privacy policy
- Stats are for user's benefit (not shared without consent)

### Development Risks

**Risk**: 14 weeks is tight for this feature set
**Mitigation**:
- Start with Phase 1 MVP (streaming only)
- Add social features incrementally
- Use existing libraries (just_audio, fl_chart)
- Parallel desktop and mobile development
- Cut features if timeline slips (EQ can wait)

**Risk**: Desktop integration more complex than expected
**Mitigation**:
- Prototype API server in Week 1
- Test on real devices early
- Simple REST first, WebSocket later
- Document all APIs clearly

---

## Success Metrics

### Technical KPIs

- **Connection Success Rate**: >95% within 10 seconds
- **Streaming Quality**: <3% buffer events on good WiFi
- **App Startup Time**: <2 seconds cold start
- **Battery Usage**: <5% per hour of streaming
- **Crash Rate**: <0.1% of sessions

### User Engagement KPIs

- **Daily Active Users**: 40% of total users
- **Stats Dashboard Views**: 60% of users check weekly
- **Friend Connections**: Average 3 friends per user
- **Share Actions**: 2+ shares per user per week
- **Listening Time**: 45+ minutes average session

### Feature Adoption KPIs

- **Offline Cache**: 50% of users cache at least 10 albums
- **Equalizer**: 30% of users customize EQ
- **Playlists**: 70% create at least one playlist
- **Remote Control**: 40% use desktop control feature

---

## Post-MVP Roadmap

### v1.1 - Enhanced Discovery (Weeks 15-18)
- Discover new music through friends' listening activity
- "Friends are listening to..." feed
- Trending among friends
- Collaborative playlists

### v1.2 - Advanced Stats (Weeks 19-22)
- Yearly listening wrapped (Spotify-style)
- Listening goals & challenges
- Compare stats with friends
- Export stats to CSV/JSON

### v1.3 - Streaming Integration (Weeks 23-26)
- YouTube Music integration (find owned tracks)
- Spotify comparison ("You own this in better quality")
- Import playlists from other services

### v2.0 - Full Social Network (Months 6-9)
- Public profiles (optional)
- Discover users with similar taste
- Music discussion threads
- Curated community playlists

---

## Appendix

### Technology Evaluation

**Why just_audio over media_kit?**
- media_kit (libmpv) is desktop-only
- just_audio works on iOS & Android
- Good format support (FLAC, MP3, AAC, ALAC)
- Easy integration with streams
- Active maintenance

**Why Riverpod over Bloc?**
- Simpler syntax
- Compile-time safety
- Better DevTools
- Easier testing
- Growing community

**Why Drift over Hive?**
- SQL flexibility for complex queries
- Better migration support
- Type-safe queries
- Relations support
- Performance at scale

### External Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Audio
  just_audio: ^0.9.40
  audio_service: ^0.18.12

  # Networking
  dio: ^5.4.0
  web_socket_channel: ^3.0.0
  multicast_dns: ^0.3.2

  # Database
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.18

  # UI
  fl_chart: ^0.68.0
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0

  # Utilities
  path_provider: ^2.1.2
  shared_preferences: ^2.2.2
  intl: ^0.19.0
  uuid: ^4.3.3

dev_dependencies:
  build_runner: ^2.4.8
  riverpod_generator: ^2.4.0
  drift_dev: ^2.18.0
  mockito: ^5.4.4
```

### Testing Strategy

**Unit Tests** (Target: 80% coverage)
- Services layer (all business logic)
- Providers (state management)
- Data models & transformations
- Utilities & helpers

**Widget Tests**
- Critical UI components
- User interactions
- State changes
- Error states

**Integration Tests**
- End-to-end flows (discover → connect → browse → play)
- Desktop communication
- Friend matching
- Stats calculation

**Manual Testing**
- iOS devices (iPhone 12+, iPad)
- Android devices (Samsung, Pixel)
- Different network conditions
- Desktop OS variations

---

**Document Version**: 1.0
**Last Updated**: November 3, 2025
**Next Review**: After Phase 1 Completion

---
