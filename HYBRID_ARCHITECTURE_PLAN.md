# 🎵 TrustTune Hybrid Architecture Migration Plan

**Branch**: `features/hybrid-approach`
**Goal**: Enable both torrent downloads AND streaming sources (YouTube, etc.) in a unified architecture
**Status**: Planning → Implementation

---

## 📋 Table of Contents

- [Executive Summary](#executive-summary)
- [Current Architecture Analysis](#current-architecture-analysis)
- [Target Architecture](#target-architecture)
- [Migration Roadmap](#migration-roadmap)
- [Technical Implementation](#technical-implementation)
- [Task Checklist](#task-checklist)
- [References](#references)

---

## Executive Summary

### The Vision

**Hybrid Music Platform**: Combine the audiophile quality of torrents with the instant gratification of streaming.

**Why This Matters:**
- **Torrents**: FLAC, DSD, hi-res audio (audiophile quality)
- **Streaming**: Instant playback, no wait time
- **Together**: Best availability, user choice, resilience

**Current State:**
- ✅ 40% Generic (query parsing, MusicBrainz, AI ranking, adapter pattern)
- ❌ 60% Torrent-specific (models, GUI, download flow)

**Target State:**
- ✅ 90% Generic (unified source model)
- ✅ 10% Source-specific adapters (pluggable)

### Key Insight: We Already Have Plugin Architecture!

```python
# karma_player/services/search/adapter_base.py
class IndexerAdapter(ABC):
    @abstractmethod
    async def search(self, query: str) -> List[TorrentResult]
```

**This exists!** We just need to:
1. Generalize `TorrentResult` → `MusicSource`
2. Add new adapters (YouTube, Piped, etc.)
3. Update GUI to handle both types

---

## Current Architecture Analysis

### Data Flow (Current)

```
User Query
    ↓
AI Parse → "Radiohead OK Computer"
    ↓
MusicBrainz → Canonical metadata + MBID
    ↓
SearchEngine → Runs all IndexerAdapters concurrently
    ↓
    ├─ JackettAdapter → TorrentResult[]
    ├─ LeetxAdapter → TorrentResult[]
    └─ (Future) YouTubeAdapter → ???
    ↓
Rank by quality_score (seeders + format + size)
    ↓
GUI displays results with "seeders" badges
    ↓
User clicks "Download" → transmission-daemon
```

### Tight Coupling Points

#### 1. **Data Models** (`karma_player/models/torrent.py`)

```python
@dataclass
class TorrentResult:
    title: str
    magnet_link: str          # ← Torrent-only
    seeders: int              # ← Torrent-only
    leechers: int             # ← Torrent-only
    format: Optional[str]
    bitrate: Optional[str]
```

**Problem**: All adapters must return torrent-specific fields.

#### 2. **GUI Display** (`gui/lib/screens/search_screen.dart`)

```dart
// Line 409: Displays seeders
Chip(label: Text('${torrent['seeders']} seeders'))

// Line 201-237: Download handler
final magnetLink = torrent['magnet_link'];
transmissionClient.addTorrent(magnetLink: magnetLink);
```

**Problem**: UI expects torrent fields and magnet links.

#### 3. **Quality Scoring** (`karma_player/models/torrent.py:52-98`)

```python
def quality_score(self) -> float:
    format_bonus = 200 if self.format == "FLAC" else 150
    seeder_bonus = min(self.seeders * 2, 100)  # ← Torrent-only
    return format_bonus + seeder_bonus
```

**Problem**: Scoring logic assumes seeders exist.

### What's Already Generic ✅

1. **Adapter Pattern**: `IndexerAdapter` with health tracking
2. **Search Orchestration**: Multi-source concurrent search
3. **AI Parsing**: Query → Artist/Album/Track
4. **MusicBrainz**: Canonical metadata lookup
5. **SearchEngine**: Deduplication, filtering, sorting

**These stay the same!** Just need to work with generic sources.

---

## Target Architecture

### Unified Source Model

```python
# NEW: karma_player/models/source.py

from enum import Enum
from dataclasses import dataclass
from typing import Optional, List

class SourceType(Enum):
    TORRENT = "torrent"
    YOUTUBE = "youtube"
    PIPED = "piped"
    JIOSAAVN = "jiosaavn"
    LOCAL = "local"

@dataclass
class MusicSource:
    """Universal music source (torrent, stream, local file)"""

    # === COMMON FIELDS (all sources) ===
    id: str                    # infohash OR video_id OR file_path
    title: str
    artist: str
    album: Optional[str]
    format: str                # FLAC, MP3, M4A, WEBA, OPUS
    bitrate: Optional[str]     # "320kbps" OR "128kbps"
    duration_ms: int
    source_type: SourceType
    indexer: str               # "jackett" OR "youtube" OR "piped"

    # === SOURCE URL ===
    url: str                   # magnet:... OR https:... OR file:...

    # === QUALITY & RANKING ===
    quality_score: float       # Unified 0-1000 scoring

    # === TORRENT-SPECIFIC (Optional) ===
    seeders: Optional[int] = None
    leechers: Optional[int] = None
    size_bytes: Optional[int] = None
    uploaded_at: Optional[datetime] = None

    # === STREAMING-SPECIFIC (Optional) ===
    codec: Optional[str] = None          # "opus", "m4a", "weba"
    thumbnail_url: Optional[str] = None
    page_url: Optional[str] = None       # YouTube video page

    @property
    def is_streamable(self) -> bool:
        """Can this source be played immediately?"""
        return self.source_type in [SourceType.YOUTUBE, SourceType.PIPED, SourceType.JIOSAAVN]

    @property
    def is_downloadable(self) -> bool:
        """Does this source require download?"""
        return self.source_type == SourceType.TORRENT

    @property
    def availability(self) -> str:
        """User-facing availability label"""
        if self.is_streamable:
            return "instant"
        elif self.is_downloadable and self.seeders and self.seeders > 0:
            return "download"
        else:
            return "unavailable"

@dataclass
class RankedSource:
    """AI-ranked music source with explanation"""
    source: MusicSource
    rank: int
    explanation: str
    tags: List[str]           # ["lossless", "fast", "instant", "hi-res"]
```

### Generalized Adapter Pattern

```python
# NEW: karma_player/services/search/source_adapter.py

class SourceAdapter(ABC):
    """Abstract base for ANY music source adapter"""

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable adapter name (e.g., 'Jackett', 'YouTube')"""
        pass

    @property
    @abstractmethod
    def source_type(self) -> SourceType:
        """Type of sources this adapter provides"""
        pass

    @property
    def is_healthy(self) -> bool:
        """Health check with circuit breaker (same as before)"""
        # ... existing health tracking logic

    @abstractmethod
    async def search(self, query: str) -> List[MusicSource]:
        """Search and return generic MusicSource objects"""
        pass
```

### Example: Refactored Torrent Adapter

```python
# UPDATED: karma_player/services/search/adapters/jackett.py

class JackettAdapter(SourceAdapter):
    source_type = SourceType.TORRENT
    name = "Jackett"

    async def search(self, query: str) -> List[MusicSource]:
        # Existing Jackett search logic
        raw_results = await self._search_jackett_api(query)

        # Convert to MusicSource
        return [self._torrent_to_source(r) for r in raw_results]

    def _torrent_to_source(self, raw: dict) -> MusicSource:
        """Convert Jackett result to MusicSource"""
        return MusicSource(
            id=self._extract_infohash(raw['magnet_link']),
            title=raw['title'],
            artist=self._parse_artist(raw['title']),
            album=self._parse_album(raw['title']),
            format=self._parse_format(raw['title']),
            bitrate=self._parse_bitrate(raw['title']),
            duration_ms=0,  # Not available from torrent
            source_type=SourceType.TORRENT,
            indexer="jackett",
            url=raw['magnet_link'],  # magnet: link
            quality_score=self._calc_torrent_quality(raw),

            # Torrent-specific
            seeders=raw['seeders'],
            leechers=raw['leechers'],
            size_bytes=raw['size_bytes'],
            uploaded_at=raw['uploaded_at'],
        )

    def _calc_torrent_quality(self, raw: dict) -> float:
        """Calculate quality score for torrent"""
        format_bonus = {'FLAC': 300, 'MP3-320': 200, 'MP3-V0': 150}.get(
            self._parse_format(raw['title']), 100
        )
        seeder_bonus = min(raw['seeders'] * 2, 100)
        size_bonus = min(raw['size_bytes'] / (1024**2) / 10, 50)
        return format_bonus + seeder_bonus + size_bonus
```

### Example: New YouTube Adapter

```python
# NEW: karma_player/services/search/adapters/youtube.py

import yt_dlp

class YouTubeAdapter(SourceAdapter):
    source_type = SourceType.YOUTUBE
    name = "YouTube"

    async def search(self, query: str) -> List[MusicSource]:
        """Search YouTube and return streaming sources"""
        ydl_opts = {
            'format': 'bestaudio/best',
            'quiet': True,
            'no_warnings': True,
        }

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            results = ydl.extract_info(
                f"ytsearch10:{query}",
                download=False
            )

            return [
                await self._video_to_source(video)
                for video in results['entries'][:10]
            ]

    async def _video_to_source(self, video: dict) -> MusicSource:
        """Convert YouTube video to MusicSource"""
        # Get best audio stream
        audio_format = max(
            (f for f in video['formats'] if f.get('acodec') != 'none'),
            key=lambda f: f.get('abr', 0)  # Sort by audio bitrate
        )

        return MusicSource(
            id=video['id'],
            title=video['title'],
            artist=video.get('uploader', 'Unknown'),
            album=None,
            format=self._codec_to_format(audio_format['acodec']),
            bitrate=f"{audio_format.get('abr', 128)}kbps",
            duration_ms=video.get('duration', 0) * 1000,
            source_type=SourceType.YOUTUBE,
            indexer="youtube",
            url=audio_format['url'],  # Direct streaming URL
            quality_score=self._calc_youtube_quality(audio_format),

            # Streaming-specific
            codec=audio_format.get('acodec'),
            thumbnail_url=video.get('thumbnail'),
            page_url=f"https://youtube.com/watch?v={video['id']}",
        )

    def _calc_youtube_quality(self, audio_format: dict) -> float:
        """Calculate quality score for YouTube stream"""
        codec_scores = {'opus': 250, 'm4a': 220, 'mp3': 180}
        codec_bonus = codec_scores.get(audio_format.get('acodec', ''), 150)

        bitrate_bonus = audio_format.get('abr', 128) / 2  # kbps → score

        availability_bonus = 150  # Instant streaming!

        return codec_bonus + bitrate_bonus + availability_bonus
```

### Updated Search Flow

```python
# UPDATED: karma_player/services/search_orchestrator.py

class SearchOrchestrator:
    async def search(self, query: str) -> SearchResult:
        # ... existing AI parsing + MusicBrainz lookup ...

        # Search ALL adapters (torrent + streaming)
        sources = await self.search_engine.search(search_query)

        # Sources now include BOTH torrents and streams!
        # Example results:
        # [
        #   MusicSource(title="OK Computer [FLAC]", source_type=TORRENT, seeders=42),
        #   MusicSource(title="OK Computer (Full Album)", source_type=YOUTUBE, ...),
        #   MusicSource(title="Radiohead - Paranoid Android", source_type=YOUTUBE, ...),
        # ]

        # Rank by unified quality score
        ranked = self._rank_sources(sources)

        return SearchResult(
            query=query,
            sources=ranked,
            total_found=len(sources),
        )
```

---

## Migration Roadmap

### 🚀 PHASE 1: Foundation (v0.4.0) - Backend Refactor

**Goal**: Generalize backend to support multiple source types without breaking existing functionality.

**Duration**: ~40 hours (1-2 weeks)

#### Tasks

1. **Create new source models** ✓
   - [ ] Create `karma_player/models/source.py`
   - [ ] Define `SourceType` enum
   - [ ] Define `MusicSource` dataclass
   - [ ] Define `RankedSource` dataclass
   - [ ] Add properties: `is_streamable`, `is_downloadable`, `availability`

2. **Create generalized adapter base** ✓
   - [ ] Create `karma_player/services/search/source_adapter.py`
   - [ ] Define `SourceAdapter(ABC)` base class
   - [ ] Copy health tracking logic from `IndexerAdapter`
   - [ ] Update abstract method: `search() -> List[MusicSource]`

3. **Refactor existing torrent adapters** ✓
   - [ ] Update `JackettAdapter` to inherit from `SourceAdapter`
   - [ ] Implement `_torrent_to_source()` conversion method
   - [ ] Update quality scoring to use unified scale
   - [ ] Test: Ensure existing Jackett searches still work
   - [ ] Update `LeetxAdapter` similarly
   - [ ] Test: Ensure 1337x searches still work

4. **Update SearchEngine** ✓
   - [ ] Update `SearchEngine.__init__()` to accept `List[SourceAdapter]`
   - [ ] Update `search()` return type to `List[MusicSource]`
   - [ ] Keep deduplication logic (by `id` instead of `infohash`)
   - [ ] Update sorting to use `MusicSource.quality_score`

5. **Update SearchOrchestrator** ✓
   - [ ] Update `SearchResult` to use `List[RankedSource]`
   - [ ] Update `_generate_explanation()` to handle both source types
   - [ ] Update `_generate_tags()` to add "instant" for streamable sources
   - [ ] Test: Full search flow works end-to-end

6. **Update API endpoints** ✓
   - [ ] Update `search_api.py` to serialize `MusicSource`
   - [ ] Ensure JSON output includes `source_type` field
   - [ ] Add `is_streamable` and `is_downloadable` flags
   - [ ] Test: API returns correct JSON structure

7. **Backward compatibility** ✓
   - [ ] Keep `TorrentResult` class for now (deprecated)
   - [ ] Add migration helper: `MusicSource.to_torrent_result()`
   - [ ] Update tests to use new models
   - [ ] Deprecation warning in `TorrentResult.__init__()`

**Acceptance Criteria**:
- ✅ All existing tests pass
- ✅ Torrent search still works (Jackett + 1337x)
- ✅ API returns `source_type: "torrent"` for all results
- ✅ No GUI changes required yet (backward compatible JSON)

---

### 🎵 PHASE 2: Add YouTube Streaming (v0.5.0)

**Goal**: Add YouTube as a streaming source alongside torrents.

**Duration**: ~20 hours (3-5 days)

#### Tasks

1. **Add YouTube dependencies** ✓
   - [ ] Add `yt-dlp` to `pyproject.toml`
   - [ ] Run `poetry install`
   - [ ] Test: `yt-dlp --version` works

2. **Create YouTube adapter** ✓
   - [ ] Create `karma_player/services/search/adapters/youtube.py`
   - [ ] Implement `YouTubeAdapter(SourceAdapter)`
   - [ ] Implement `search()` using `yt-dlp`
   - [ ] Implement `_video_to_source()` conversion
   - [ ] Implement `_calc_youtube_quality()` scoring
   - [ ] Handle errors gracefully (network issues, blocked videos)

3. **Add YouTube to search pipeline** ✓
   - [ ] Update `SearchEngine` initialization to include `YouTubeAdapter`
   - [ ] Add config option: `ENABLE_YOUTUBE_SEARCH=true/false`
   - [ ] Test: Search returns BOTH torrent + YouTube results
   - [ ] Verify: Results are properly ranked by quality

4. **Test hybrid search** ✓
   - [ ] Search for "Radiohead OK Computer"
   - [ ] Verify: Returns ~10 torrents + ~10 YouTube videos
   - [ ] Verify: Quality scores make sense (FLAC > YouTube OPUS > MP3)
   - [ ] Verify: YouTube results have `is_streamable=true`

**Acceptance Criteria**:
- ✅ YouTube search works alongside torrent search
- ✅ Results include both `source_type: "torrent"` and `source_type: "youtube"`
- ✅ Streaming URLs are valid and playable
- ✅ No duplicate results (deduplication by title similarity)

---

### 🎨 PHASE 3: Hybrid GUI (v0.6.0)

**Goal**: Update Flutter UI to display and handle both source types.

**Duration**: ~30 hours (1 week)

#### Tasks

1. **Update search result display** ✓
   - [ ] Update `search_screen.dart` to read `source_type` field
   - [ ] Add source type badge (Chip widget)
     - Torrent: "🌱 {seeders} seeders"
     - YouTube: "▶️ Instant Stream"
   - [ ] Add availability indicator (instant vs download)
   - [ ] Update card styling to differentiate source types

2. **Add source-specific actions** ✓
   - [ ] For torrents: "Download" button (existing)
   - [ ] For YouTube: "Play Now" button (new)
   - [ ] For torrents with 0 seeders: Show "Unavailable" + suggest YouTube
   - [ ] Add "View on YouTube" link for streaming sources

3. **Implement streaming playback** ✓
   - [ ] Update `playback_service.dart` to handle HTTP URLs
   - [ ] Test: `media_kit` can play YouTube streaming URLs
   - [ ] Add loading state while stream initializes
   - [ ] Handle stream errors (expired URL, geo-block)
   - [ ] Add "Refresh Stream" button if URL expires

4. **Add source filter toggle** ✓
   - [ ] Add filter chips: "All" / "Torrents" / "Streaming"
   - [ ] Filter results client-side by `source_type`
   - [ ] Persist filter preference in local storage
   - [ ] Default: "All" (show both)

5. **Update download flow** ✓
   - [ ] Keep existing transmission flow for torrents
   - [ ] Add "downloading in background while streaming" message
   - [ ] Show download progress for torrents
   - [ ] Auto-switch to local file when download completes

**Acceptance Criteria**:
- ✅ Search results show both torrents and streams
- ✅ User can filter by source type
- ✅ Clicking "Download" adds torrent to transmission
- ✅ Clicking "Play Now" streams YouTube audio immediately
- ✅ UI clearly indicates which sources are instant vs download

---

### ⚡ PHASE 4: Smart Features (v0.7.0)

**Goal**: Add intelligent fallbacks and quality-of-life improvements.

**Duration**: ~40 hours (1-2 weeks)

#### Tasks

1. **Implement sibling sources (like SpotTube)** ✓
   - [ ] Add `siblings: List[MusicSource]` to `MusicSource`
   - [ ] Group YouTube results by similarity (official, audio, lyric video)
   - [ ] Allow user to swap between siblings
   - [ ] Cache sibling relationships in database

2. **Smart fallbacks** ✓
   - [ ] If torrent has 0 seeders → auto-suggest YouTube stream
   - [ ] If YouTube stream fails → suggest torrent download
   - [ ] If primary source unavailable → auto-try sibling
   - [ ] Show "Not available? Try streaming" banner

3. **Database caching** ✓
   - [ ] Create `source_match` table (track_id → source_id + source_type)
   - [ ] Cache successful matches
   - [ ] Skip search if cached match exists
   - [ ] Invalidate cache after 7 days

4. **Quality-of-life improvements** ✓
   - [ ] "Stream while downloading" mode
   - [ ] Auto-switch to local file when torrent completes
   - [ ] Remember user preference (prefer torrents vs streaming)
   - [ ] Add "Report Dead Link" button

5. **Analytics & metrics** ✓
   - [ ] Track: % searches with torrent results
   - [ ] Track: % searches with YouTube results
   - [ ] Track: User preference (download vs stream)
   - [ ] Track: Source success rate (torrent vs stream)

**Acceptance Criteria**:
- ✅ Users can swap between alternative sources easily
- ✅ Fallbacks happen automatically when primary fails
- ✅ Caching improves repeat search speed
- ✅ Hybrid experience feels seamless and intelligent

---

## Technical Implementation

### Unified Quality Scoring

**Challenge**: How to compare torrent quality (seeders + format) vs streaming quality (bitrate + codec)?

**Solution**: Normalize to 0-1000 scale

```python
def calc_quality_score(source: MusicSource) -> float:
    """Universal quality scoring across all source types"""

    if source.source_type == SourceType.TORRENT:
        # Format scoring (higher = better)
        format_scores = {
            'DSD': 400,      # DSD (highest audiophile quality)
            'FLAC': 300,     # Lossless
            'ALAC': 290,     # Apple Lossless
            'MP3-320': 200,  # High bitrate MP3
            'MP3-V0': 150,   # Variable bitrate
            'MP3-256': 120,
            'MP3-128': 80,
        }
        format_bonus = format_scores.get(source.format, 100)

        # Seeder scoring (availability)
        seeder_bonus = min((source.seeders or 0) * 2, 100)

        # Size bonus (larger = higher quality for music)
        size_mb = (source.size_bytes or 0) / (1024 * 1024)
        size_bonus = min(size_mb / 10, 50)

        return format_bonus + seeder_bonus + size_bonus

    elif source.source_type in [SourceType.YOUTUBE, SourceType.PIPED]:
        # Codec scoring
        codec_scores = {
            'opus': 250,     # Best web codec
            'm4a': 220,      # AAC
            'vorbis': 200,
            'mp3': 180,
        }
        codec_bonus = codec_scores.get(source.codec, 150)

        # Bitrate scoring
        bitrate_kbps = int(source.bitrate.replace('kbps', '')) if source.bitrate else 128
        bitrate_bonus = min(bitrate_kbps / 2, 100)

        # Availability bonus (instant streaming!)
        availability_bonus = 150

        return codec_bonus + bitrate_bonus + availability_bonus

    return 100  # Default for unknown types
```

**Result**:
- FLAC torrent (50 seeders): ~450 points
- YouTube OPUS (256kbps): ~528 points
- Dead torrent (0 seeders): ~300 points
- Low-quality YouTube: ~380 points

**YouTube often scores higher due to instant availability!**

### Handling Streaming URLs

**Challenge**: YouTube URLs expire after ~6 hours.

**Solution**: Lazy URL resolution + refresh mechanism

```python
class MusicSource:
    _cached_url: Optional[str] = None
    _url_expires_at: Optional[datetime] = None

    @property
    def url(self) -> str:
        """Get streaming URL, refresh if expired"""
        if self.source_type == SourceType.YOUTUBE:
            if self._url_expired():
                self._refresh_url()
        return self._cached_url

    def _refresh_url(self):
        """Re-fetch fresh streaming URL from YouTube"""
        with yt_dlp.YoutubeDL() as ydl:
            info = ydl.extract_info(self.id, download=False)
            audio = max(info['formats'], key=lambda f: f.get('abr', 0))
            self._cached_url = audio['url']
            self._url_expires_at = datetime.now() + timedelta(hours=6)
```

### API Response Format

```json
{
  "query": "radiohead ok computer",
  "total_found": 23,
  "sources": [
    {
      "id": "a3f2b8...",
      "title": "Radiohead - OK Computer [1997] [FLAC] [24bit/96kHz]",
      "artist": "Radiohead",
      "album": "OK Computer",
      "format": "FLAC",
      "bitrate": "24/96",
      "source_type": "torrent",
      "indexer": "jackett",
      "url": "magnet:?xt=urn:btih:a3f2b8...",
      "quality_score": 485.2,
      "is_streamable": false,
      "is_downloadable": true,
      "availability": "download",
      "seeders": 42,
      "leechers": 5,
      "size_bytes": 485726208,
      "rank": 1,
      "explanation": "🏆 Best match • Lossless quality • 24/96 • 42 seeders (fast) • 463 MB",
      "tags": ["best_quality", "lossless", "hi-res", "fast"]
    },
    {
      "id": "dQw4w9WgXcQ",
      "title": "Radiohead - OK Computer (Full Album)",
      "artist": "Radiohead",
      "album": "OK Computer",
      "format": "OPUS",
      "bitrate": "160kbps",
      "source_type": "youtube",
      "indexer": "youtube",
      "url": "https://rr4---sn-...",
      "quality_score": 535.0,
      "is_streamable": true,
      "is_downloadable": false,
      "availability": "instant",
      "codec": "opus",
      "thumbnail_url": "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
      "page_url": "https://youtube.com/watch?v=dQw4w9WgXcQ",
      "rank": 2,
      "explanation": "#2 Top result • OPUS • 160kbps • Instant streaming",
      "tags": ["instant", "fast"]
    }
  ]
}
```

---

## Task Checklist

### Phase 1: Foundation ✓

- [ ] **Models**: Create `karma_player/models/source.py`
  - [ ] Define `SourceType` enum
  - [ ] Define `MusicSource` dataclass
  - [ ] Define `RankedSource` dataclass
  - [ ] Add helper properties and methods

- [ ] **Adapters**: Create `karma_player/services/search/source_adapter.py`
  - [ ] Define `SourceAdapter(ABC)` base class
  - [ ] Copy health tracking from `IndexerAdapter`
  - [ ] Update abstract methods

- [ ] **Refactor Jackett**: Update `adapters/jackett.py`
  - [ ] Inherit from `SourceAdapter`
  - [ ] Implement `_torrent_to_source()` conversion
  - [ ] Update quality scoring
  - [ ] Test with real searches

- [ ] **Refactor 1337x**: Update `adapters/leetx.py`
  - [ ] Same refactoring as Jackett
  - [ ] Test with real searches

- [ ] **Update SearchEngine**: Modify `search/engine.py`
  - [ ] Accept `List[SourceAdapter]`
  - [ ] Return `List[MusicSource]`
  - [ ] Update deduplication logic
  - [ ] Test end-to-end

- [ ] **Update Orchestrator**: Modify `search_orchestrator.py`
  - [ ] Update `SearchResult` model
  - [ ] Update ranking logic
  - [ ] Update explanation generation
  - [ ] Test full flow

- [ ] **Update API**: Modify `api/search_api.py`
  - [ ] Serialize `MusicSource` to JSON
  - [ ] Add source type fields
  - [ ] Test API responses

- [ ] **Testing**: Verify backward compatibility
  - [ ] All existing tests pass
  - [ ] Manual testing: torrent search works
  - [ ] API returns correct structure

### Phase 2: YouTube Streaming ✓

- [ ] **Dependencies**: Add YouTube support
  - [ ] Add `yt-dlp` to `pyproject.toml`
  - [ ] Run `poetry install`
  - [ ] Verify installation

- [ ] **YouTube Adapter**: Create `adapters/youtube.py`
  - [ ] Implement `YouTubeAdapter(SourceAdapter)`
  - [ ] Implement search using `yt-dlp`
  - [ ] Implement quality scoring
  - [ ] Handle errors and edge cases

- [ ] **Integration**: Add YouTube to pipeline
  - [ ] Register adapter in SearchEngine
  - [ ] Add config flag
  - [ ] Test hybrid search

- [ ] **Testing**: Verify hybrid results
  - [ ] Search returns both types
  - [ ] Quality ranking is sensible
  - [ ] URLs are valid

### Phase 3: Hybrid GUI ✓

- [ ] **Display**: Update `search_screen.dart`
  - [ ] Add source type badges
  - [ ] Add availability indicators
  - [ ] Style source cards

- [ ] **Actions**: Add source-specific buttons
  - [ ] "Download" for torrents
  - [ ] "Play Now" for streams
  - [ ] Fallback suggestions

- [ ] **Streaming**: Update `playback_service.dart`
  - [ ] Handle HTTP streaming URLs
  - [ ] Test with YouTube URLs
  - [ ] Handle errors

- [ ] **Filtering**: Add source type filter
  - [ ] Add filter UI
  - [ ] Implement filtering logic
  - [ ] Persist preferences

### Phase 4: Smart Features ✓

- [ ] **Siblings**: Implement alternative sources
  - [ ] Add sibling grouping
  - [ ] Add swap UI
  - [ ] Test switching

- [ ] **Fallbacks**: Add smart suggestions
  - [ ] Detect unavailable sources
  - [ ] Suggest alternatives
  - [ ] Auto-retry logic

- [ ] **Caching**: Add database caching
  - [ ] Create migrations
  - [ ] Implement cache logic
  - [ ] Test cache hits

- [ ] **QoL**: Quality of life improvements
  - [ ] Stream while downloading
  - [ ] Auto-switch to local
  - [ ] Preference learning

---

## References

### Inspiration: SpotTube Architecture

- **Repo**: https://github.com/KRTirtho/spotube
- **Key Files**:
  - `lib/services/sourced_track/sourced_track.dart` - Source abstraction
  - `lib/services/sourced_track/sources/youtube.dart` - YouTube implementation
  - `lib/models/playback/track_sources.dart` - Source models
- **Packages Used**:
  - `youtube_explode_dart` - YouTube audio extraction (Dart)
  - `drift` - Database ORM
  - `riverpod` - State management

### Python Packages

- **yt-dlp**: YouTube metadata + streaming URL extraction
  - Docs: https://github.com/yt-dlp/yt-dlp
  - Install: `poetry add yt-dlp`
  - Usage: `ydl.extract_info("ytsearch:query")`

### Flutter Packages (Already Installed)

- **media_kit**: Audio playback (supports HTTP streams!)
  - Already in `pubspec.yaml`
  - Works with both local files and streaming URLs

### Design Principles

1. **Adapter Pattern**: Keep sources pluggable
2. **Fail Gracefully**: Source unavailable? Fall back to others
3. **User Choice**: Don't force one approach, let user decide
4. **Quality First**: Score by actual audio quality, not just availability
5. **Hybrid > Siloed**: Mixing is more powerful than separating

---

## Notes

- **Branch**: All work happens on `features/hybrid-approach`
- **Testing**: Test each phase before moving to next
- **Backward Compatibility**: Phase 1 must not break existing torrent functionality
- **User Impact**: No UI changes until Phase 3 (backend changes invisible)

---

**Last Updated**: 2025-10-28
**Status**: Planning Complete → Ready for Implementation
