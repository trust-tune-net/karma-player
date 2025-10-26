# 🏗️ TrustTune Technical Architecture

> Detailed technical specifications for Phase 0 MVP

---

## System Overview

```
┌────────────────────────────────────────────────────────────┐
│                    User's Computer                          │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │  TrustTune.app (Flutter)                           │   │
│  │  - Search UI                                       │   │
│  │  - Results display                                 │   │
│  │  - Download manager                                │   │
│  │  - Music player                                    │   │
│  └──────────────┬─────────────────────────────────────┘   │
│                 │ localhost:8765 (HTTP/WS)                │
│  ┌──────────────▼─────────────────────────────────────┐   │
│  │  Python Service (FastAPI)                          │   │
│  │  - Torrent engine (libtorrent)                     │   │
│  │  - File manager                                    │   │
│  │  - Search aggregator                               │   │
│  │  - Database (SQLite)                               │   │
│  └──────────────┬─────────────────────────────────────┘   │
│                 │                                          │
└─────────────────┼──────────────────────────────────────────┘
                  │ HTTPS (rate-limited)
┌─────────────────▼──────────────────────────────────────────┐
│              Community API Server                          │
│         https://api.trusttune.community                    │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │  AI Services (Groq/Together.ai/Mistral)            │   │
│  │  - Query parsing                                   │   │
│  │  - MusicBrainz filtering                           │   │
│  │  - Torrent ranking                                 │   │
│  │  - Result explanation                              │   │
│  └────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────┐   │
│  │  Rate Limiting & Auth (Redis + PostgreSQL)         │   │
│  └────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────┘
```

---

## Component Specifications

### 1. Flutter Desktop App

**Framework:** Flutter 3.29+

**Key Packages:**
- `http` - API communication
- `web_socket_channel` - Real-time updates
- `media_kit` - Audio playback (MPV wrapper)
- `riverpod` - State management
- `drift` - Local database (if needed)
- `window_manager` - Window controls

**Screens:**
1. **Search Screen**
   - Text input (conversational)
   - Quick filters (quality, type)
   - Loading states with AI thinking messages

2. **Questions Screen**
   - Radio buttons / checkboxes
   - AI-generated options
   - Skip option (use defaults)

3. **Results Screen**
   - Card-based layout
   - AI explanations
   - Download buttons
   - "Show more" pagination

4. **Download Manager**
   - Progress bars
   - Speed indicators
   - Seeding status
   - File locations

5. **Player Screen**
   - Now playing info
   - Queue management
   - Volume, seek controls
   - Album art (from MusicBrainz)

6. **Settings (Optional)**
   - Music folder location
   - Download limits
   - API provider selection
   - About / version info

**State Management:**

```dart
// Search flow state
@riverpod
class SearchState extends _$SearchState {
  Future<void> search(String query) async {
    state = const AsyncValue.loading();

    try {
      // Call local Python service
      final response = await ref.read(apiClientProvider).search(query);
      state = AsyncValue.data(response);
    } catch (error) {
      state = AsyncValue.error(error);
    }
  }
}

// Download state
@riverpod
class DownloadManager extends _$DownloadManager {
  Map<String, DownloadProgress> downloads = {};

  void startDownload(TorrentResult torrent) {
    // WebSocket connection to Python service
    final ws = ref.read(wsProvider);
    ws.send({'action': 'download', 'magnet': torrent.magnetLink});
  }
}
```

---

### 2. Python Service (FastAPI)

**Framework:** FastAPI 0.110+

**Directory Structure:**
```
karma_player/
├── api/
│   ├── server.py           # FastAPI app
│   ├── routes/
│   │   ├── search.py       # Search endpoints
│   │   ├── download.py     # Download management
│   │   └── player.py       # Playback control
│   └── websocket.py        # Real-time updates
├── services/
│   ├── ai_client.py        # Community API client
│   ├── musicbrainz.py      # MusicBrainz lookup
│   ├── torrent_search.py   # DHT + Jackett
│   ├── torrent_engine.py   # libtorrent wrapper
│   ├── file_manager.py     # Organization + tagging
│   └── reddit_scraper.py   # Quality signals
├── models/
│   ├── search.py           # Request/response models
│   ├── torrent.py          # Torrent data classes
│   └── config.py           # User settings
├── database/
│   ├── schema.py           # SQLite schema
│   └── dao.py              # Data access
└── main.py                 # Entry point
```

**API Endpoints:**

```python
# Search
POST /api/search
  Body: {query: str, preferences: dict}
  Returns: {search_id: str, status: "processing"}

WS /ws/search/{search_id}
  Events:
    - {type: "question", data: {...}}
    - {type: "progress", message: str}
    - {type: "results", data: [...]}

# Downloads
POST /api/download
  Body: {magnet: str, destination: str}
  Returns: {download_id: str}

WS /ws/download/{download_id}
  Events:
    - {type: "progress", percent: float, speed: str}
    - {type: "complete", path: str}

# Player
POST /api/player/play
  Body: {file_path: str}

POST /api/player/pause
POST /api/player/stop
GET /api/player/status
```

**Services Implementation:**

```python
# services/ai_client.py
class CommunityAPIClient:
    def __init__(self):
        self.base_url = "https://api.trusttune.community/v1"
        self.device_id = self._get_device_id()

    async def parse_query(self, query: str) -> ParsedQuery:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/search/parse",
                json={"query": query},
                headers={"X-Device-ID": self.device_id}
            )
            return ParsedQuery(**response.json())

    async def filter_musicbrainz(
        self, results: List[MBResult], query: ParsedQuery
    ) -> MBSelection:
        # Rate-limited call to Community API
        ...

    async def rank_torrents(
        self, torrents: List[TorrentResult], preferences: dict
    ) -> RankedResults:
        # AI ranking with explanations
        ...
```

```python
# services/torrent_engine.py
import libtorrent as lt

class TorrentEngine:
    def __init__(self, download_dir: Path):
        self.session = lt.session()
        self.session.listen_on(6881, 6891)
        self.downloads = {}

    def add_torrent(
        self, magnet: str, callback: Callable
    ) -> str:
        params = {
            "save_path": str(self.download_dir),
            "storage_mode": lt.storage_mode_t.storage_mode_sparse,
        }
        handle = lt.add_magnet_uri(self.session, magnet, params)

        download_id = str(uuid.uuid4())
        self.downloads[download_id] = {
            "handle": handle,
            "callback": callback
        }

        return download_id

    def get_progress(self, download_id: str) -> DownloadProgress:
        handle = self.downloads[download_id]["handle"]
        status = handle.status()

        return DownloadProgress(
            percent=status.progress * 100,
            download_rate=status.download_rate,
            upload_rate=status.upload_rate,
            num_seeds=status.num_seeds,
            state=status.state
        )
```

---

### 3. Community API Server

**Hosting:** Railway.app / Fly.io (initially)

**Tech Stack:**
- FastAPI (Python)
- Redis (rate limiting, caching)
- PostgreSQL (user accounts, quotas)
- Groq SDK (primary AI)
- Together.ai SDK (fallback)
- Cloudflare (CDN, DDoS protection)

**Directory Structure:**
```
api-server/
├── app/
│   ├── main.py
│   ├── auth.py             # Device ID, rate limiting
│   ├── routes/
│   │   ├── search.py
│   │   └── quota.py
│   ├── ai/
│   │   ├── groq_client.py
│   │   ├── together_client.py
│   │   └── prompts/
│   │       ├── parse_query.txt
│   │       ├── filter_mb.txt
│   │       └── rank_torrents.txt
│   └── database/
│       ├── models.py
│       └── redis.py
├── Dockerfile
└── railway.toml
```

**Rate Limiting:**

```python
# auth.py
from redis import Redis
from datetime import datetime, timedelta

redis = Redis(host="localhost", port=6379)

async def check_rate_limit(device_id: str) -> RateLimitStatus:
    key = f"quota:{device_id}:{datetime.now().date()}"

    current = redis.get(key)
    if current is None:
        redis.setex(key, timedelta(days=1), "0")
        current = 0
    else:
        current = int(current)

    # Anonymous tier: 50 searches/day
    # Each search = ~3 API calls average
    limit = 50

    if current >= limit:
        return RateLimitStatus(
            allowed=False,
            used=current,
            limit=limit,
            resets_at=datetime.now() + timedelta(days=1)
        )

    return RateLimitStatus(allowed=True, used=current, limit=limit)

async def increment_quota(device_id: str):
    key = f"quota:{device_id}:{datetime.now().date()}"
    redis.incr(key)
```

**AI Providers with Fallback:**

```python
# ai/groq_client.py
class AIClient:
    def __init__(self):
        self.providers = [
            GroqProvider(api_key=os.getenv("GROQ_API_KEY")),
            TogetherProvider(api_key=os.getenv("TOGETHER_API_KEY")),
            MistralProvider(api_key=os.getenv("MISTRAL_API_KEY")),
        ]

    async def complete(self, prompt: str) -> str:
        for provider in self.providers:
            try:
                return await provider.complete(prompt)
            except RateLimitError:
                continue  # Try next provider
            except Exception as e:
                logger.error(f"{provider.__class__}: {e}")
                continue

        raise AllProvidersFailedError()
```

---

## Data Models

### Search Flow Data

```python
# Parsed user query
@dataclass
class ParsedQuery:
    artist: Optional[str]
    album: Optional[str]
    track: Optional[str]
    year: Optional[int]
    query_type: Literal["album", "track", "artist"]
    confidence: float

# MusicBrainz result
@dataclass
class MBResult:
    mbid: str
    title: str
    artist: str
    release_date: str
    country: str
    label: Optional[str]
    barcode: Optional[str]

# Torrent result
@dataclass
class TorrentResult:
    title: str
    magnet_link: str
    size_bytes: int
    seeders: int
    leechers: int
    format: Optional[str]  # FLAC, MP3, etc.
    bitrate: Optional[str]
    source: str  # DHT, Jackett, etc.
    quality_score: float

# AI ranking
@dataclass
class RankedResult:
    torrent: TorrentResult
    rank: int
    explanation: str
    tags: List[str]  # ["best_quality", "trusted", "fast"]
```

---

## Database Schema

```sql
-- SQLite local database (on user's machine)

CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE search_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    query TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    results_count INTEGER,
    selected_torrent TEXT
);

CREATE TABLE downloads (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    magnet TEXT NOT NULL,
    title TEXT,
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,
    file_path TEXT,
    size_bytes INTEGER,
    status TEXT  -- downloading, seeding, paused, complete
);

CREATE TABLE library (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT UNIQUE NOT NULL,
    artist TEXT,
    album TEXT,
    title TEXT,
    year INTEGER,
    format TEXT,
    added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    play_count INTEGER DEFAULT 0,
    mbid TEXT
);
```

```sql
-- PostgreSQL (Community API server)

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT UNIQUE NOT NULL,
    first_seen TIMESTAMP DEFAULT NOW(),
    last_seen TIMESTAMP DEFAULT NOW(),
    tier TEXT DEFAULT 'anonymous'  -- anonymous, free, contributor, supporter
);

CREATE TABLE quota_usage (
    id SERIAL PRIMARY KEY,
    device_id TEXT NOT NULL,
    date DATE NOT NULL,
    searches_used INTEGER DEFAULT 0,
    UNIQUE(device_id, date)
);

CREATE TABLE api_logs (
    id SERIAL PRIMARY KEY,
    device_id TEXT,
    endpoint TEXT,
    timestamp TIMESTAMP DEFAULT NOW(),
    response_time_ms INTEGER,
    provider TEXT,  -- groq, together, mistral
    success BOOLEAN
);
```

---

## Security & Privacy

### Client-Side

**No Sensitive Data Stored:**
- Downloads encrypted at rest? (optional, Phase 1)
- Search history: Local only, user can clear
- No cloud sync without explicit consent

**Device ID:**
```python
# Generate privacy-friendly device ID
import hashlib
import platform

def generate_device_id() -> str:
    # Combine machine-specific info (not personally identifiable)
    info = f"{platform.machine()}-{platform.system()}"
    # Add random salt stored locally
    salt = get_or_create_salt()

    return hashlib.sha256(f"{info}-{salt}".encode()).hexdigest()[:16]
```

### API Server

**Rate Limiting:**
- Per-device, not per-IP (privacy)
- No tracking across devices
- No user profiling

**Data Retention:**
- API logs: 30 days
- Quota usage: 90 days
- No search query logging (privacy)

**Open Source:**
- API server code: Public repo
- Community can audit
- Self-hosting supported

---

## Deployment

### Desktop App

**macOS:**
```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/TrustTune.app
# Package: create-dmg or electron-builder equivalent
```

**Windows:**
```bash
flutter build windows --release
# Output: build/windows/runner/Release/
# Package: Inno Setup or NSIS
```

**Linux:**
```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
# Package: AppImage, .deb, .rpm
```

### Python Service

**Bundled with App:**
```
TrustTune.app/
└── Contents/
    ├── MacOS/
    │   └── TrustTune (Flutter executable)
    └── Resources/
        ├── app.asar.unpacked/  (if using Electron)
        └── python/
            ├── python3.11 (bundled interpreter)
            ├── karma_player/
            └── site-packages/
```

**Auto-start:**
```dart
// Flutter starts Python service on launch
Future<void> startPythonService() async {
  final pythonPath = await getPythonBundlePath();
  final process = await Process.start(
    pythonPath,
    ['-m', 'karma_player.main'],
    environment: {'PORT': '8765'}
  );

  // Wait for server ready
  await waitForServer('http://localhost:8765/health');
}
```

### Community API

**Railway.app Deployment:**
```toml
# railway.toml
[build]
builder = "DOCKERFILE"

[deploy]
startCommand = "uvicorn app.main:app --host 0.0.0.0 --port $PORT"

[env]
GROQ_API_KEY = "${{GROQ_API_KEY}}"
REDIS_URL = "${{REDIS_URL}}"
DATABASE_URL = "${{DATABASE_URL}}"
```

**Cloudflare (CDN + DDoS):**
```
DNS: api.trusttune.community → CNAME → railway.app
Cloudflare: Proxy enabled, SSL, DDoS protection
```

---

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Search → Results** | <5 seconds | End-to-end |
| **AI Response** | <500ms | Community API latency |
| **Download Start** | <1 second | After user clicks |
| **App Startup** | <2 seconds | Cold start |
| **Memory Usage** | <500 MB | Idle state |
| **API Uptime** | >99.5% | Monthly |

---

## Monitoring & Observability

### Client-Side

```python
# Optional telemetry (opt-in)
class Telemetry:
    def __init__(self, enabled: bool):
        self.enabled = enabled

    def track_search(self, query: str, results_count: int):
        if not self.enabled:
            return

        # Send anonymous metrics
        send_metric({
            "event": "search_complete",
            "results": results_count,
            "timestamp": datetime.now()
        })
```

### API Server

```python
# Prometheus metrics
from prometheus_client import Counter, Histogram

search_requests = Counter(
    'search_requests_total',
    'Total search requests',
    ['provider', 'status']
)

search_duration = Histogram(
    'search_duration_seconds',
    'Search request duration',
    ['endpoint']
)
```

**Grafana Dashboards:**
- API requests per minute
- Provider success rates
- Rate limit hits
- Error rates
- Response time p50/p95/p99

---

## Testing Strategy

### Unit Tests
- AI client mocking
- Torrent engine logic
- File organization
- Quality scoring

### Integration Tests
- Flutter ↔ Python API
- Python ↔ Community API
- Download flow end-to-end

### E2E Tests
- Search flow (Grandma test)
- Download + play
- Error handling

### Load Tests
- Community API: 100 concurrent users
- Torrent engine: 10 simultaneous downloads
- Database queries under load

---

## Next Steps

See [IMPLEMENTATION.md](./IMPLEMENTATION.md) for week-by-week build plan.

---

*Last updated: January 2025*
