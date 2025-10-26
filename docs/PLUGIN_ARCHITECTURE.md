# 🔌 TrustTune Plugin Architecture

## Overview

TrustTune uses a **plugin-based adapter pattern** to support multiple music sources. This architecture makes it trivial to add new indexers, scrapers, or search sources without modifying core code.

**Key Principle:** Each source is a self-contained adapter that speaks a common language (`TorrentResult`).

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│  CLI / GUI / API                                            │
│  (User interfaces)                                          │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│  SearchOrchestrator                                         │
│  • Parses queries (AI)                                      │
│  • MusicBrainz lookup                                       │
│  • Coordinates search                                       │
│  • Ranks results (AI + scoring)                             │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│  SearchEngine (Multi-source coordinator)                    │
│  • Manages adapter pool                                     │
│  • Parallel execution                                       │
│  • Health monitoring (circuit breaker)                      │
│  • Deduplication (by infohash)                              │
│  • Quality sorting                                          │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┬──────────────┐
        │            │            │              │
        ▼            ▼            ▼              ▼
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ AdapterBase  │ AdapterBase  │ AdapterBase  │ AdapterBase  │
│ (Abstract)   │ (Abstract)   │ (Abstract)   │ (Abstract)   │
├──────────────┼──────────────┼──────────────┼──────────────┤
│   Jackett    │    1337x     │   YourNew    │   Reddit     │
│   Adapter    │   Adapter    │   Adapter    │   Scraper    │
└──────────────┴──────────────┴──────────────┴──────────────┘
      │              │              │              │
      │              │              │              │
      ▼              ▼              ▼              ▼
┌──────────────────────────────────────────────────────────┐
│  External Sources                                        │
│  • Jackett (18+ indexers)                                │
│  • 1337x.to                                              │
│  • Reddit                                                │
│  • Your Custom Source                                    │
└──────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. `IndexerAdapter` (Abstract Base Class)

**Location:** `karma_player/services/search/adapter_base.py`

All adapters inherit from this ABC. It provides:

#### **Interface Contract:**
```python
class IndexerAdapter(ABC):
    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable indexer name"""
        pass

    @abstractmethod
    async def search(self, query: str) -> List[TorrentResult]:
        """Execute search and return normalized results"""
        pass
```

#### **Built-in Features** (No need to implement):
- **Health tracking** - Consecutive failure counting
- **Circuit breaker** - Auto-disable after 3 failures
- **Cooldown** - 5-minute recovery period
- **Health recovery** - Auto-reset when cooldown expires

#### **Health Management:**
```python
# Automatic circuit breaker
if self._consecutive_failures >= 3:
    # Adapter disabled for 5 minutes
    return False

# Call this in your adapter:
self._update_health(success=True)   # On successful search
self._update_health(success=False)  # On failure
```

---

### 2. `SearchEngine` (Adapter Coordinator)

**Location:** `karma_player/services/search/engine.py`

Manages multiple adapters and coordinates searches.

#### **Responsibilities:**
1. **Parallel execution** - All adapters search concurrently
2. **Health filtering** - Only queries healthy adapters
3. **Error handling** - Adapter failures don't crash search
4. **Deduplication** - Removes duplicate torrents (by infohash)
5. **Quality sorting** - Sorts by `quality_score` property

#### **Usage:**
```python
# Initialize with adapters
adapters = [AdapterJackett(...), Adapter1337x(), YourAdapter()]
engine = SearchEngine(adapters=adapters)

# Search (all adapters run in parallel)
results = await engine.search(
    query="radiohead ok computer",
    format_filter="FLAC",   # Optional
    min_seeders=5           # Filter low-seeder torrents
)
```

---

### 3. `TorrentResult` (Normalized Data Model)

**Location:** `karma_player/models/torrent.py`

All adapters must return this standardized format.

```python
@dataclass
class TorrentResult:
    # Required fields
    title: str          # Torrent title
    magnet_link: str    # Magnet URI (must start with "magnet:")
    size_bytes: int     # Size in bytes
    seeders: int        # Number of seeders
    leechers: int       # Number of leechers
    uploaded_at: datetime  # Upload timestamp
    indexer: str        # Source name (e.g., "Jackett", "1337x")

    # Optional metadata (extracted from title/description)
    format: Optional[str] = None   # FLAC, MP3, AAC, ALAC
    bitrate: Optional[str] = None  # "320kbps", "24/96", "V0"
    source: Optional[str] = None   # CD, Vinyl, WEB, etc.

    @property
    def quality_score(self) -> float:
        """
        Auto-calculated quality score for ranking:
        - DSD: ~400+ points
        - FLAC 24-bit: 260+ points
        - FLAC 16-bit: 200 points
        - MP3 320kbps: 150 points
        - MP3 V0: 140 points
        - + seeder bonus (max 100)
        - + size bonus (max 50)
        """
```

---

## Adding a New Source (Step-by-Step)

### **Example: Adding Pirate Bay Adapter**

#### **Step 1: Create Adapter File**

Create `/karma_player/services/search/adapter_piratebay.py`:

```python
"""The Pirate Bay torrent indexer adapter."""

import asyncio
import re
from datetime import datetime, timezone
from typing import List
from urllib.parse import quote_plus

import aiohttp
from bs4 import BeautifulSoup

from karma_player.services.search.adapter_base import IndexerAdapter
from karma_player.models.torrent import TorrentResult
from karma_player.services.search.metadata import MetadataExtractor


class AdapterPirateBay(IndexerAdapter):
    """Adapter for The Pirate Bay."""

    BASE_URL = "https://thepiratebay.org"
    TIMEOUT = 10

    @property
    def name(self) -> str:
        return "ThePirateBay"

    async def search(self, query: str) -> List[TorrentResult]:
        """Search The Pirate Bay for music torrents."""
        try:
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            }

            async with aiohttp.ClientSession(headers=headers) as session:
                # TPB search URL (category 100 = Audio)
                search_url = f"{self.BASE_URL}/search/{quote_plus(query)}/0/99/100"

                async with asyncio.timeout(self.TIMEOUT):
                    async with session.get(search_url) as response:
                        if response.status != 200:
                            self._update_health(success=False)
                            return []

                        html = await response.text()

                # Parse HTML
                soup = BeautifulSoup(html, "html.parser")
                rows = soup.select("table#searchResult tr")

                results = []
                for row in rows[1:]:  # Skip header
                    try:
                        result = self._parse_row(row)
                        if result:
                            results.append(result)
                    except Exception:
                        continue

                self._update_health(success=True)
                return results

        except asyncio.TimeoutError:
            self._update_health(success=False)
            return []
        except Exception:
            self._update_health(success=False)
            return []

    def _parse_row(self, row) -> TorrentResult | None:
        """Parse a search result row."""
        # Extract title
        title_cell = row.select_one("div.detName a")
        if not title_cell:
            return None
        title = title_cell.text.strip()

        # Extract magnet link
        magnet_link = row.select_one("a[href^='magnet:']")
        if not magnet_link:
            return None
        magnet_link = magnet_link["href"]

        # Extract seeders/leechers
        font_tags = row.select("td font")
        seeders = int(font_tags[0].text) if len(font_tags) > 0 else 0
        leechers = int(font_tags[1].text) if len(font_tags) > 1 else 0

        # Extract size
        desc_tag = row.select_one("font.detDesc")
        size_bytes = 0
        if desc_tag:
            size_match = re.search(r"Size ([\d\.]+)\s*([KMGT])iB", desc_tag.text)
            if size_match:
                extractor = MetadataExtractor()
                size_bytes = extractor.parse_size(f"{size_match.group(1)} {size_match.group(2)}B")

        # Extract metadata from title
        extractor = MetadataExtractor()
        format_type = extractor.extract_format(title)
        bitrate = extractor.extract_bitrate(title)
        source = extractor.extract_source(title)

        return TorrentResult(
            title=title,
            magnet_link=magnet_link,
            size_bytes=size_bytes,
            seeders=seeders,
            leechers=leechers,
            uploaded_at=datetime.now(timezone.utc),
            indexer=self.name,
            format=format_type,
            bitrate=bitrate,
            source=source,
        )
```

#### **Step 2: Register Adapter**

Update where adapters are initialized (e.g., `cli.py`, `server.py`):

```python
from karma_player.services.search.adapter_jackett import AdapterJackett
from karma_player.services.search.adapter_1337x import Adapter1337x
from karma_player.services.search.adapter_piratebay import AdapterPirateBay  # NEW

# Initialize adapters
adapters = [
    AdapterJackett(base_url=..., api_key=...),
    Adapter1337x(),
    AdapterPirateBay(),  # NEW - No config needed
]

engine = SearchEngine(adapters=adapters)
```

#### **Step 3: Done! ✅**

That's it. Your adapter is now:
- **Health monitored** (circuit breaker built-in)
- **Parallel executed** (searches with all other adapters)
- **Deduplicated** (duplicate results auto-removed)
- **Quality sorted** (TorrentResult.quality_score)

---

## Adapter Best Practices

### 1. **Use the Built-in Health System**

```python
try:
    # Perform search
    results = await self._fetch_results(query)
    self._update_health(success=True)  # ✅ Mark success
    return results
except Exception:
    self._update_health(success=False)  # ❌ Mark failure
    return []
```

### 2. **Always Return Valid Magnet Links**

```python
# ✅ GOOD
if magnet_link and magnet_link.startswith("magnet:"):
    return TorrentResult(...)

# ❌ BAD - Will break Transmission
if link:  # Could be HTTP URL
    return TorrentResult(magnet_link=link, ...)
```

### 3. **Use MetadataExtractor for Parsing**

```python
from karma_player.services.search.metadata import MetadataExtractor

extractor = MetadataExtractor()

# Extract format (FLAC, MP3, AAC)
format_type = extractor.extract_format(title)

# Extract bitrate (320kbps, 24/96, V0)
bitrate = extractor.extract_bitrate(title)

# Extract source (CD, Vinyl, WEB)
source = extractor.extract_source(title)

# Parse size strings
size_bytes = extractor.parse_size("1.5 GB")  # → 1610612736
```

### 4. **Handle Timeouts Gracefully**

```python
async with asyncio.timeout(self.TIMEOUT):
    async with session.get(url) as response:
        # ...
```

### 5. **Return Early on Errors**

```python
if response.status != 200:
    self._update_health(success=False)
    return []  # Don't raise exceptions
```

---

## Advanced: Adapter Configuration

### **Environment-Based Configuration**

```python
class AdapterJackett(IndexerAdapter):
    def __init__(
        self,
        base_url: str = None,
        api_key: str = None
    ):
        super().__init__()
        self.base_url = base_url or os.getenv("JACKETT_URL", "http://localhost:9117")
        self.api_key = api_key or os.getenv("JACKETT_API_KEY", "")
```

### **Dynamic Adapter Loading**

```python
# Future: Load adapters from config file
def load_adapters_from_config(config_path: str) -> List[IndexerAdapter]:
    config = yaml.load(config_path)
    adapters = []

    for adapter_config in config["adapters"]:
        adapter_class = import_adapter(adapter_config["type"])
        adapter = adapter_class(**adapter_config["params"])
        adapters.append(adapter)

    return adapters
```

---

## Testing Your Adapter

### **Unit Test Example**

```python
import pytest
from karma_player.services.search.adapter_piratebay import AdapterPirateBay

@pytest.mark.asyncio
async def test_piratebay_search():
    adapter = AdapterPirateBay()

    results = await adapter.search("radiohead ok computer")

    assert len(results) > 0
    assert all(r.magnet_link.startswith("magnet:") for r in results)
    assert all(r.indexer == "ThePirateBay" for r in results)
    assert adapter.is_healthy  # Should be healthy after success
```

### **Integration Test**

```python
@pytest.mark.asyncio
async def test_search_engine_with_piratebay():
    adapters = [AdapterPirateBay(), Adapter1337x()]
    engine = SearchEngine(adapters=adapters)

    results = await engine.search("miles davis kind of blue")

    # Results from multiple sources
    indexers = {r.indexer for r in results}
    assert "ThePirateBay" in indexers or "1337x" in indexers

    # Deduplicated
    infohashes = [r.infohash for r in results]
    assert len(infohashes) == len(set(infohashes))

    # Sorted by quality
    scores = [r.quality_score for r in results]
    assert scores == sorted(scores, reverse=True)
```

---

## Current Adapters

### 1. **AdapterJackett** (karma_player/services/search/adapter_jackett.py)

- **Source:** Jackett proxy (supports 100+ indexers)
- **Protocol:** Torznab API (XML)
- **Features:**
  - Multi-indexer support (`indexer_id="all"`)
  - Category filtering (Audio categories)
  - Retry logic for cold starts (Easypanel)
  - Only returns real magnet URIs (not proxy URLs)
- **Config:** `JACKETT_URL`, `JACKETT_API_KEY`

### 2. **Adapter1337x** (karma_player/services/search/adapter_1337x.py)

- **Source:** 1337x.to public torrent site
- **Protocol:** HTML scraping
- **Features:**
  - Parallel detail page fetching (magnet links)
  - BeautifulSoup parsing
  - Format/bitrate extraction from titles
- **Config:** None (public site)

---

## Future Adapter Ideas

### **Community Adapters (Anyone Can Build)**

1. **AdapterReddit** - Scrape music subreddits for torrent links
2. **AdapterRateYourMusic** - Scrape RYM for album recommendations
3. **AdapterSoulseek** - Integrate Soulseek P2P network
4. **AdapterBandcamp** - Search Bandcamp free downloads
5. **AdapterArchive.org** - Public domain music from Internet Archive
6. **AdapterYouTube** - Convert YouTube playlists to music search
7. **AdapterSpotifyPlaylist** - Import Spotify playlists, search elsewhere

### **Federation Adapters (Phase 2)**

1. **AdapterTrustTuneNode** - Query other TrustTune federation nodes
2. **AdapterIPFS** - Distributed music storage
3. **AdapterGun** - Decentralized graph database

---

## Why This Architecture?

### **Benefits:**

1. **Extensibility** - Add sources without changing core code
2. **Resilience** - One adapter failure doesn't break search
3. **Performance** - All adapters run in parallel (async)
4. **Quality** - Automatic deduplication and scoring
5. **Health** - Circuit breaker prevents hammering dead sources
6. **Simplicity** - Each adapter is ~200 lines of focused code

### **Real-World Impact:**

```
Single query → 3 adapters → 150 results
                ↓
          Deduplication (by infohash)
                ↓
          75 unique torrents
                ↓
          Quality sorting
                ↓
          Top 50 results
```

**User sees:** Best quality, deduplicated, fastest sources — automatically.

---

## Contributing Adapters

Want to add a new source? **We welcome contributions!**

1. **Create adapter** following the template above
2. **Test thoroughly** (unit + integration tests)
3. **Document config** (environment variables, API keys)
4. **Submit PR** with:
   - Adapter code
   - Tests
   - README update
   - Example usage

**Example PR title:** `feat: Add Pirate Bay adapter for music search`

---

## Summary

**TrustTune's plugin architecture is:**
- ✅ **Simple** - Implement 2 methods, inherit 1 class
- ✅ **Resilient** - Built-in health monitoring and circuit breaker
- ✅ **Parallel** - All sources searched concurrently
- ✅ **Normalized** - One data model (`TorrentResult`)
- ✅ **Quality-First** - Automatic scoring and deduplication

**To add a new source:**
1. Create `adapter_yoursite.py`
2. Inherit `IndexerAdapter`
3. Implement `search()` → return `List[TorrentResult]`
4. Register in adapter list
5. Done! ✅

**Like BitTorrent, TrustTune is protocol-first.** Anyone can implement an adapter, run a node, or build alternative clients. The architecture is open, simple, and designed for federation.
