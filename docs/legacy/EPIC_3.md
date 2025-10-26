## Epic 3: Torrent Search & Selection

**Epic Goal:** Enable users to search multiple torrent indexers with a unified interface, returning normalized, music-focused results sorted by quality indicators. Architecture prioritizes adapter modularity, graceful degradation, and music-specific metadata extraction.

**Epic Definition of Done:**
- Search returns results from 2+ working indexers
- Results normalized to standard schema (title, magnet, size, seeders, format, bitrate)
- Health monitoring tracks indexer failures
- Deduplication by infohash prevents duplicate results
- Format inference extracts FLAC/MP3/320/V0 from titles
- Terminal UI displays color-coded results sorted by quality score
- User selects result by letter, gets magnet link for download

---

### Task 3.1: Core Search Engine & Result Schema

**Description:** Build the core search orchestrator with standardized result format

**Technical Decisions:**
- **Result Schema:** Dataclass with fields: `title`, `magnet_link`, `size_bytes`, `seeders`, `leechers`, `uploaded_at`, `indexer`, `format`, `bitrate`, `source`
- **Deduplication:** Extract infohash from magnet links, filter duplicates
- **Quality Scoring:** `seeders * 2 + min(size_gb * 10, 50)` to prioritize high-seeder lossless releases

**DoD:**
```python
@dataclass
class TorrentResult:
    title: str
    magnet_link: str
    size_bytes: int
    seeders: int
    leechers: int
    uploaded_at: datetime
    indexer: str
    format: Optional[str]  # FLAC, MP3, AAC
    bitrate: Optional[str]  # 320, V0, V2
    source: Optional[str]   # WEB, CD, Vinyl
    
    @property
    def quality_score(self) -> float:
        """Higher is better: seeders + size bonus for lossless"""
        pass

class SearchEngine:
    async def search(self, query: str, 
                    format_filter: Optional[str] = None,
                    min_seeders: int = 5) -> List[TorrentResult]:
        """Search all healthy indexers, deduplicate, sort by quality"""
        pass
```

**Acceptance Criteria:**
- SearchEngine.search() returns list of TorrentResult objects
- Results deduplicated by infohash (extract from magnet link)
- Results sorted by quality_score descending
- Empty list on no results (not exception)
- Caches results for 30 minutes (dict cache MVP, Redis later)

**Tests:**
- Unit: `test_result_deduplication()` - same infohash returns 1 result
- Unit: `test_quality_scoring()` - FLAC 50 seeders > MP3 100 seeders
- Unit: `test_empty_results()` - no crash on zero results
- Integration: Mock 2 indexers returning overlapping results, verify dedup

---

### Task 3.2: Indexer Adapter Interface & Base Class

**Description:** Define adapter pattern for indexer implementations

**Technical Decisions:**
- **Base Class:** Abstract `IndexerAdapter` with `name`, `is_healthy`, `search()` methods
- **Health Tracking:** Track last success timestamp and failure count per adapter
- **Circuit Breaker:** Auto-disable adapter after 3 consecutive failures
- **Timeout:** 10-second timeout per indexer query

**DoD:**
```python
class IndexerAdapter(ABC):
    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable indexer name"""
        pass
    
    @property
    def is_healthy(self) -> bool:
        """False if 3+ consecutive failures or circuit open"""
        pass
    
    @abstractmethod
    async def search(self, query: str) -> List[TorrentResult]:
        """Execute search, return normalized results, raise on failure"""
        pass
    
    def _update_health(self, success: bool):
        """Track success/failure for circuit breaker"""
        pass
```

**Acceptance Criteria:**
- Subclassing IndexerAdapter requires only implementing `name` and `search()`
- Health tracking automatic via `_update_health()` calls
- Unhealthy adapters skipped by SearchEngine
- Health resets to healthy after 5-minute cooldown + successful test query

**Tests:**
- Unit: `test_circuit_breaker()` - 3 failures → is_healthy = False
- Unit: `test_health_recovery()` - cooldown period allows retry
- Mock: Adapter that always fails, verify skipped after threshold

---

### Task 3.3: Implement 1337x Adapter

**Description:** Scrape 1337x.to for music torrents

**Technical Decisions:**
- **HTTP Library:** `aiohttp` for async requests
- **Parsing:** BeautifulSoup4 with CSS selectors
- **Selectors:** `.table-list tbody tr` for rows, `.coll-1 a:nth-of-type(2)` for title
- **Two-stage:** Search page → detail page for magnet link (parallelize detail fetches)

**DoD:**
```python
class Adapter1337x(IndexerAdapter):
    async def search(self, query: str) -> List[TorrentResult]:
        # GET https://1337x.to/search/{query}/1/
        # Parse search results page
        # Parallel fetch detail pages for top 20 results
        # Extract magnet links
        # Return normalized TorrentResult list
        pass
```

**Acceptance Criteria:**
- Extracts: title, seeders, leechers, size, uploaded date
- Fetches magnet link from detail page (handle missing magnets gracefully)
- Parses size strings: "1.5 GB" → 1610612736 bytes
- Extracts format/bitrate via regex: `(FLAC|MP3|320|V0|V2)`
- Returns empty list on network errors (not exception)
- Timeout after 10 seconds

**Tests:**
- Unit: `test_size_parsing()` - "750 MB" → 786432000
- Unit: `test_format_extraction()` - "Album [FLAC]" → format="FLAC"
- Integration: Mock HTML response, verify parsing
- E2E: Real query "aphex twin ambient", assert >0 results with valid magnets

**Edge Cases:**
- Missing size field → size_bytes = 0
- Missing seeder count → seeders = 0
- Malformed row → skip row, continue parsing
- Detail page timeout → skip that result
- No magnet link on detail page → skip result

---

### Task 3.4: Implement Rutracker Adapter (Optional, if accessible)

**Description:** Scrape Rutracker.org for music torrents

**Technical Decisions:**
- **Encoding:** UTF-8 with Cyrillic support
- **Authentication:** Cookies-based login (store session cookie)
- **Rate Limiting:** Max 1 req/second to avoid blocks

**DoD:**
- Login flow: POST credentials → store session cookie
- Search with cookie authentication
- Parse Cyrillic titles correctly
- Convert Russian date formats to datetime

**Acceptance Criteria:**
- Handles 401/403 by re-authenticating
- Parses tables with mixed Cyrillic/Latin text
- Rate limits to 1 req/sec (use `asyncio.sleep()`)

**Tests:**
- Unit: Test date parsing "Вчера в 15:30" → datetime
- Integration: Mock auth flow, verify cookie storage
- E2E: Requires valid credentials (skip in CI)

**Deferred to Phase 2 if time-constrained** (focus on 1337x first)

---

### Task 3.5: Format & Quality Inference Engine

**Description:** Extract music metadata from release titles using regex patterns

**Technical Decisions:**
- **Format Patterns:** `(FLAC|MP3|AAC|ALAC|OGG|Opus)` (case-insensitive)
- **Bitrate Patterns:** `(320|256|192|V0|V2)`
- **Source Patterns:** `(WEB|CD|Vinyl|DVD|BD)`
- **Fallback:** If no match, format = None (not "Unknown")

**DoD:**
```python
class MetadataExtractor:
    @staticmethod
    def extract_format(title: str) -> Optional[str]:
        """Extract FLAC, MP3, etc."""
        pass
    
    @staticmethod
    def extract_bitrate(title: str) -> Optional[str]:
        """Extract 320, V0, etc."""
        pass
    
    @staticmethod
    def extract_source(title: str) -> Optional[str]:
        """Extract WEB, CD, Vinyl"""
        pass
```

**Acceptance Criteria:**
- Returns None on no match (not empty string or "Unknown")
- Case-insensitive matching
- Prefers first match if multiple formats in title

**Tests:**
- Unit: `test_format_extraction()`
  - "Album [FLAC]" → "FLAC"
  - "Album (MP3 320)" → "MP3"
  - "Album" → None
- Unit: `test_bitrate_extraction()`
  - "Album [FLAC]" → None
  - "Album [MP3 V0]" → "V0"
- Unit: `test_source_extraction()`
  - "Album [WEB FLAC]" → "WEB"
  - "Album [CD Rip]" → "CD"

---

### Task 3.6: Result Display & Terminal UI

**Description:** Display search results with color-coded formatting in terminal

**Technical Decisions:**
- **Colors:** Rich library for terminal formatting
- **Color Scheme:** Green = FLAC/lossless, Yellow = MP3 320, White = other
- **Layout:** Lettered list [A]-[Z], then [AA]-[AZ] for 26+ results
- **Fields:** Letter | Title (truncated) | Format | Size | Seeds | Health Score

**DoD:**
```python
class ResultDisplay:
    def show_results(self, results: List[TorrentResult], 
                    max_display: int = 20):
        """Print formatted, color-coded result table"""
        pass
    
    def prompt_selection(self) -> Optional[str]:
        """Get user selection, return letter or None"""
        pass
```

**Acceptance Criteria:**
- Truncate titles to 60 chars with "..." ellipsis
- Display format: `[A] Artist - Album [FLAC] | 1.2 GB | 45 seeds | Score: 140.5`
- Green text for FLAC/lossless formats
- Yellow text for MP3 320kbps
- White/default for other formats
- Letter labels [A]-[Z], then [AA]-[AZ] for 26+
- Show "(more results available)" if results > max_display
- Prompt: "Select [A-T], [M]ore, or [Q]uit: "

**Tests:**
- Unit: `test_title_truncation()` - 100 char title → 60 chars + "..."
- Unit: `test_letter_generation()` - result 27 → "AA"
- Integration: Mock terminal, verify ANSI color codes
- E2E: Display 30 results, verify pagination works

---

### Task 3.7: Selection & Output Handler

**Description:** Handle user selection and return magnet link

**DoD:**
```python
class SelectionHandler:
    def parse_input(self, user_input: str, 
                   results: List[TorrentResult]) -> Optional[TorrentResult]:
        """Parse letter input, return selected result"""
        pass
    
    def get_magnet_link(self, result: TorrentResult) -> str:
        """Return magnet link for selected result"""
        pass
```

**Acceptance Criteria:**
- Parse single letter: "A" → results[0]
- Parse double letter: "AA" → results[26]
- Case-insensitive: "a" == "A"
- Invalid input → return None (not exception)
- Return full magnet link (starts with "magnet:?xt=urn:btih:")

**Tests:**
- Unit: `test_letter_parsing("A", 10 results)` → results[0]
- Unit: `test_invalid_input("Z", 5 results)` → None
- Unit: `test_case_insensitive("a")` → results[0]

---

### Task 3.8: Error Handling & Resilience

**Description:** Implement comprehensive error handling across all components

**Technical Decisions:**
- **Network Errors:** Catch `aiohttp.ClientError`, return empty list
- **Parsing Errors:** Catch `BeautifulSoup` exceptions, log warning, continue
- **Timeout:** 10-second timeout per indexer, don't block on slow sites
- **Logging:** Use `structlog` for JSON-formatted logs

**DoD:**
- All adapter methods return empty list on failure (not exceptions)
- SearchEngine continues on single adapter failure
- Logs capture: timestamp, indexer, error type, query
- User sees: "Indexer X failed, continuing with others..."

**Acceptance Criteria:**
- Network timeout → log warning, return []
- HTTP 500 → log error, return []
- Parsing exception → log error with title, skip result
- At least 1 working indexer → search succeeds
- All indexers fail → return empty list with message

**Tests:**
- Unit: Mock adapter raising `TimeoutError`, verify handled
- Integration: Mock 2 adapters (1 fails, 1 succeeds), verify partial results
- E2E: Kill indexer during test, verify graceful degradation

---

### Task 3.9: Integration Testing & End-to-End Validation

**Description:** Validate complete search flow from query to selection

**Test Scenarios:**
1. **Happy Path:** Query "radiohead" → 15 results from 2 indexers → select [C] → get magnet
2. **Single Indexer Down:** 1 indexer fails → still get results from other
3. **Duplicate Results:** Same torrent on 2 indexers → appears once
4. **Format Filtering:** Query with format="FLAC" → only FLAC results
5. **Zero Results:** Query "asdfqwerzxcv" → empty list, polite message
6. **Invalid Selection:** Select [Z] when only 10 results → error, re-prompt

**DoD:**
- All 6 scenarios pass with real queries (not mocked)
- Tests use actual indexer websites (mark as integration, not unit)
- Tests run in <30 seconds total
- CI can skip these with `pytest -m "not integration"`

**Acceptance Criteria:**
- E2E test suite in `tests/integration/test_search_flow.py`
- Uses pytest fixtures for SearchEngine setup
- Marks as `@pytest.mark.integration` for CI control
- Captures logs for debugging failures
- Asserts on result count, quality scores, deduplication

---

### Task 3.10: Optional Jackett Integration (Phase 2)

**Description:** Add Jackett proxy adapter for 500+ indexer support

**Deferred to Phase 2** - Only implement if MVP proves viable and team has capacity

**Technical Decisions:**
- **Jackett API:** Torznab endpoint `/api/v2.0/indexers/{id}/results/torznab/api`
- **XML Parsing:** Parse RSS 2.0 with torznab namespace extensions
- **Categories:** Filter to music categories (3000-3090)

**DoD:**
```python
class JackettAdapter(IndexerAdapter):
    def __init__(self, base_url: str, api_key: str, 
                 indexer_ids: List[str]):
        pass
    
    async def search(self, query: str) -> List[TorrentResult]:
        # Query Jackett's Torznab API
        # Parse XML response
        # Return normalized results
        pass
```

**Acceptance Criteria:**
- Connects to local Jackett instance (http://localhost:9117)
- Queries multiple indexers via single adapter
- Parses torznab XML attributes (size, seeders, infohash)
- Handles Jackett downtime gracefully

**Benefits:**
- Instant access to 500+ maintained indexers
- No scraper maintenance when sites change
- Private tracker support (if user has accounts)

**Defer Reasoning:**
- Adds external dependency (user must run Jackett)
- Overkill for MVP (2-3 indexers sufficient)
- Can add later without architectural changes

---

## Epic-Level Testing Strategy

**Unit Tests (Fast, No Network):**
- Result schema validation
- Format/bitrate extraction regex
- Size parsing (GB/MB → bytes)
- Quality scoring algorithm
- Deduplication by infohash
- Health tracking & circuit breaker logic

**Integration Tests (Mocked Network):**
- Adapter with mocked HTTP responses
- SearchEngine with mock adapters
- Error handling with injected failures
- Caching behavior

**E2E Tests (Real Network, Slow):**
- Query real indexers
- Verify result structure
- Test user selection flow
- Validate magnet link format
- Mark with `@pytest.mark.integration`

**Performance Benchmarks:**
- Search latency <5 seconds for 2 indexers
- Result display <100ms for 50 results
- Memory usage <50 MB for typical query

---

## Epic Success Metrics

**Functional:**
- ✅ Search returns results from 2+ indexers
- ✅ Results deduplicated (no duplicate infohashes)
- ✅ Format inference 90%+ accurate on FLAC/MP3
- ✅ User can select result and get valid magnet link
- ✅ Graceful degradation when 1 indexer fails

**Non-Functional:**
- ✅ Search completes in <5 seconds
- ✅ Code coverage >80% for core modules
- ✅ Zero unhandled exceptions in normal operation
- ✅ Logs capture all errors with context

**User Experience:**
- ✅ Terminal colors work (or degrade gracefully)
- ✅ Result display readable (not cluttered)
- ✅ Selection by letter intuitive
- ✅ Error messages helpful (not technical stack traces)

---

## Post-Epic: Integration with Project Vision

**Connects to MVP Phase 1 (from mvp_vision.md):**
- Torrent search provides **external source** for the network-first architecture
- Results feed into voting/validation system (Casual users vote on quality)
- Magnet links enable download via qBittorrent integration (Epic 4)

**Enables Network-First Evolution (Phase 2):**
- Search results cached in Gun.js for network distribution
- Community validates torrent quality → builds verified catalog
- Eventually: Search Gun.js network first, external torrents second

**Technical Debt to Address Later:**
- Replace dict cache with Redis (Phase 2)
- Add more indexers (Rutracker, private trackers)
- Implement Jackett integration for 500+ indexers
- Add retry logic with exponential backoff
- Prometheus metrics for monitoring