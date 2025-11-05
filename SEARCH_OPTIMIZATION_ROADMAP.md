# Search Optimization Roadmap

**Project:** TrustTune Desktop App - Search Performance & Decoupling
**Last Updated:** 2025-11-05
**Status:** Planning Phase

---

## Table of Contents

- [Overview](#overview)
- [Current State Analysis](#current-state-analysis)
- [Phase 1: Quick Wins](#phase-1-quick-wins-1-2-days)
- [Phase 2: Decoupling](#phase-2-decoupling-3-5-days)
- [Phase 3: Result Streaming](#phase-3-result-streaming-5-7-days)
- [Phase 4: Optimization & Scalability](#phase-4-optimization--scalability-7-10-days)
- [Testing Strategy](#testing-strategy)
- [Rollback Plan](#rollback-plan)

---

## Overview

### Goals
- ⚡ **Reduce search latency by 60-80%**
- 🎯 **Decouple torrent and streaming searches**
- 💰 **Cut API costs by 50%**
- 🚀 **Improve perceived performance by 10x**
- 🛡️ **Increase fault tolerance**

### Key Problems to Solve
1. **Blocking orchestration** - User waits for ALL adapters (5-10s)
2. **No progressive loading** - Results appear all-at-once
3. **No caching** - Repeated searches hit APIs unnecessarily
4. **Tight coupling** - Torrents + YouTube in single request
5. **Poor UX** - No debouncing, no pagination, blocking UI

---

## Current State Analysis

### Performance Metrics (Baseline)

| Metric | Current | Target (Phase 4) |
|--------|---------|------------------|
| Time to first result | 5-10s | 0.5-1s |
| API calls per search | 3 (OpenAI + Jackett + YouTube) | 1 (cached) |
| Perceived latency | 5-10s (blank screen) | 0.5s (progressive) |
| UI responsiveness | Blocked | Fully responsive |

### Architecture Issues

```
Current Flow (BLOCKING):
User → HTTP POST → [Jackett + YouTube] → Combined Results → User
         ↓               ↓
      5-10s wait    All-or-nothing
```

```
Target Flow (NON-BLOCKING):
User → HTTP POST → Jackett → Partial Results → User
    ↘ HTTP POST → YouTube → Partial Results → User
         ↓              ↓
    Independent    Progressive loading
```

---

## Phase 1: Quick Wins (1-2 days)

**Goal:** Reduce latency by 40% and API costs by 50% with minimal code changes.

### Checklist

#### ~~1.1 Add Input Debouncing (Flutter)~~ ❌ NOT NEEDED

**Status:** SKIPPED - Search only triggers on button click or Enter key press, not on text change.

**Current Behavior:**
- Search triggered by: Button click OR Enter key
- No search-as-you-type functionality
- No debouncing needed

**Note:** If we add search-as-you-type in the future, debouncing would be required. For now, the explicit search action (button/Enter) already prevents rapid API calls.

---

#### ~~1.1 Cache AI Query Parsing~~ ❌ BETTER IDEA: Skip AI Parsing Entirely ⭐ HIGH PRIORITY

**Status:** SQL-like parsing adds 200-500ms + OpenAI costs for minimal benefit.

**Current Flow (Wasteful):**
```
"radiohead" → OpenAI ($$$) → "SELECT album WHERE artist='Radiohead'" → Parse → "radiohead"
```

**Better Approach:** Pass natural language directly to adapters!
- Jackett handles natural language ✅
- YouTube Music handles natural language ✅
- No AI needed for 99% of desktop users

#### Implementation: Add Feature Flag to Disable AI Parsing

**File:** `karma_player/services/simple_search.py`

- [ ] Add `use_ai_parsing: bool = False` parameter to `search()`
- [ ] Skip AI conversion when flag is False
- [ ] Pass query directly to search engine
- [ ] Test: Search without AI parsing works

**File:** `karma_player/api/search_api.py`

- [ ] Add optional `use_ai` query parameter (default: False)
- [ ] Keep `/api/search` as simple (no AI)
- [ ] Create `/api/search/advanced` for power users (with AI)

**Code Snippet:**
```python
# simple_search.py
async def search(
    self,
    query: str,
    format_filter: Optional[str] = None,
    min_seeders: int = 1,
    limit: int = 20,
    use_ai_parsing: bool = False,  # NEW: Default to False (no AI)
    progress_callback: Optional[Callable] = None
) -> SimpleSearchResult:
    """Execute simple search"""
    start_time = time.time()

    logger.info(f"🔍 Search query: '{query}' (AI parsing: {use_ai_parsing})")

    await progress(10, "Parsing query...")

    if use_ai_parsing and query.upper().startswith("SELECT"):
        # SQL-like query for power users
        music_query = SQLLikeParser.parse(query)
        sql_query = query
        logger.info(f"   → SQL query detected")
    elif use_ai_parsing:
        # AI conversion (opt-in)
        sql_query = await NaturalLanguageToSQL.convert(query)
        music_query = SQLLikeParser.parse(sql_query)
        logger.info(f"   → AI converted to: {sql_query}")
    else:
        # Default: Direct pass-through (FAST!)
        music_query = MusicQuery(
            query=query,
            min_seeders=min_seeders,
            limit=limit,
            format=format_filter
        )
        sql_query = None
        logger.info(f"   → Direct pass-through (no AI)")

    # Override with explicit filters
    if format_filter:
        music_query.format = format_filter
    if min_seeders > music_query.min_seeders:
        music_query.min_seeders = min_seeders

    # Search directly with user query
    search_str = query  # Pass as-is to adapters!
    logger.info(f"   → Searching: '{search_str}'")

    torrents = await self.search_engine.search(
        query=search_str,
        format_filter=music_query.format,
        min_seeders=music_query.min_seeders
    )

    # ... rest of ranking logic ...
```

```python
# search_api.py
@app.post("/api/search", response_model=SearchResponse)
async def search(request: SearchRequest):
    """Simple search (no AI, fast!)"""
    result = await search_service.search(
        query=request.query,
        format_filter=request.format_filter,
        min_seeders=request.min_seeders,
        limit=request.limit,
        use_ai_parsing=False  # Disabled by default
    )
    return _build_response(result)


@app.post("/api/search/advanced", response_model=SearchResponse)
async def search_advanced(request: SearchRequest):
    """Advanced search with AI parsing (for power users)"""
    result = await search_service.search(
        query=request.query,
        format_filter=request.format_filter,
        min_seeders=request.min_seeders,
        limit=request.limit,
        use_ai_parsing=True  # Enabled for advanced queries
    )
    return _build_response(result)
```

**Success Criteria:**
- Search "radiohead ok computer" → no AI call, instant search
- Logs show "Direct pass-through (no AI)"
- 200-500ms faster response time
- No OpenAI costs for regular searches
- `/api/search/advanced` still available for power users

---

#### 1.2 Add Per-Adapter Timeouts (Backend) ⭐ HIGH PRIORITY

**File:** `karma_player/services/search/engine.py`

- [ ] Import `asyncio` (already present)
- [ ] Add `timeout: float = 8.0` parameter to `search()` method
- [ ] Wrap each adapter search with `asyncio.wait_for()`
- [ ] Log timeout warnings
- [ ] Continue with partial results on timeout
- [ ] Test: Slow adapter doesn't block entire search

**Code Snippet:**
```python
async def search(
    self,
    query: str,
    format_filter: Optional[str] = None,
    min_seeders: int = 5,
    timeout_per_adapter: float = 8.0,  # NEW: 8s timeout per adapter
) -> List[MusicSource]:
    """Search all healthy sources with timeout protection."""
    healthy_adapters = [a for a in self.adapters if a.is_healthy]
    logger.info(f"🔍 Searching with {len(healthy_adapters)} healthy adapters (timeout: {timeout_per_adapter}s)")

    if not healthy_adapters:
        return []

    # Wrap each search with timeout
    async def search_with_timeout(adapter: SourceAdapter):
        try:
            return await asyncio.wait_for(
                adapter.search(query),
                timeout=timeout_per_adapter
            )
        except asyncio.TimeoutError:
            logger.warning(f"⏱️  {adapter.name} timed out after {timeout_per_adapter}s")
            adapter._update_health(success=False)
            return []  # Return empty list, continue with other adapters

    # Execute all searches concurrently
    tasks = [search_with_timeout(adapter) for adapter in healthy_adapters]
    results_lists = await asyncio.gather(*tasks, return_exceptions=True)

    # Combine results (rest of logic unchanged)
    all_results = []
    for adapter, results in zip(healthy_adapters, results_lists):
        if isinstance(results, Exception):
            logger.error(f"   ❌ {adapter.name} failed: {results}")
            adapter._update_health(success=False)
            continue

        logger.info(f"   ✓ {adapter.name}: {len(results)} results")
        adapter._update_health(success=True)
        all_results.extend(results)

    # Rest of deduplication/filtering logic...
```

**Success Criteria:**
- Jackett timeout after 8s doesn't block YouTube results
- User sees partial results (YouTube only) if Jackett times out
- Logs clearly indicate which adapter timed out

---

#### 1.3 Reduce Default Limit (Backend + Flutter)

**Files:**
- `karma_player/api/search_api.py` (line 100)
- `gui/lib/screens/search_screen.dart` (line 127)

- [ ] Change backend default: `limit: int = 50` → `limit: int = 20`
- [ ] Change Flutter request: `'limit': 50` → `'limit': 20`
- [ ] Update UI text if showing result count
- [ ] Test: Only 20 results returned and displayed

**Backend Changes:**
```python
# search_api.py line 100
class SearchRequest(BaseModel):
    query: str
    format_filter: Optional[str] = None
    min_seeders: int = 1
    limit: int = 20  # Changed from 50
```

**Flutter Changes:**
```dart
// search_screen.dart line 127
body: json.encode({
  'query': _searchController.text,
  'format_filter': null,
  'min_seeders': 1,
  'limit': 20,  // Changed from 50
}),
```

**Success Criteria:**
- API returns max 20 results
- Flutter displays max 20 results
- Faster rendering and lower bandwidth

---

### Phase 1 Testing Checklist

- [ ] Run backend tests: `poetry run pytest`
- [ ] Run Flutter analyze: `flutter analyze`
- [ ] Manual test: Search "radiohead" - verify NO OpenAI call (check backend logs)
- [ ] Manual test: Verify logs show "Direct pass-through (no AI)"
- [ ] Manual test: Disable Jackett or add delay - verify timeout handling (8s max)
- [ ] Manual test: Verify only 20 results returned (not 50)
- [ ] Manual test: Test `/api/search/advanced` with AI parsing (should work for power users)
- [ ] Performance test: Measure latency before/after
- [ ] Commit with message: "Phase 1: Disable AI parsing by default, add timeouts, reduce limits"

**Expected Results:**
- ⚡ **50-60% latency reduction** (no AI call: -200-500ms, timeouts, reduced limits)
- 💰 **90% fewer OpenAI API calls** (only on `/api/search/advanced` endpoint)
- 🛡️ **Better fault tolerance** (timeouts prevent slow adapters from blocking)
- 💸 **Significant cost savings** (no OpenAI calls for regular desktop searches)

---

## Phase 2: Decoupling (3-5 days)

**Goal:** Separate torrent and streaming searches for independent execution.

### Checklist

#### 2.1 Create Split Backend Endpoints

**File:** `karma_player/api/search_api.py`

- [ ] Create `POST /api/search/torrents` endpoint
- [ ] Create `POST /api/search/streaming` endpoint
- [ ] Keep `POST /api/search` for backward compatibility
- [ ] Add source type filtering to SimpleSearch
- [ ] Test endpoints independently

**Code Snippet:**
```python
@app.post("/api/search/torrents", response_model=SearchResponse)
async def search_torrents(request: SearchRequest):
    """Search torrents only (Jackett, 1337x)"""
    if not search_service:
        raise HTTPException(status_code=503, detail="Search service not initialized")

    logger.info(f"🔍 Torrent search: {request.query}")

    result = await search_service.search(
        query=request.query,
        format_filter=request.format_filter,
        min_seeders=request.min_seeders,
        limit=request.limit,
        source_type_filter="torrent"  # NEW PARAMETER
    )

    return _build_search_response(result)


@app.post("/api/search/streaming", response_model=SearchResponse)
async def search_streaming(request: SearchRequest):
    """Search streaming sources only (YouTube Music, Piped)"""
    if not search_service:
        raise HTTPException(status_code=503, detail="Search service not initialized")

    logger.info(f"🎵 Streaming search: {request.query}")

    result = await search_service.search(
        query=request.query,
        format_filter=request.format_filter,
        min_seeders=request.min_seeders,
        limit=request.limit,
        source_type_filter="streaming"  # NEW PARAMETER
    )

    return _build_search_response(result)


@app.post("/api/search", response_model=SearchResponse)
async def search_all(request: SearchRequest):
    """Search all sources (legacy endpoint for backward compatibility)"""
    # Existing implementation unchanged
    ...
```

**Success Criteria:**
- `/api/search/torrents` returns only torrents
- `/api/search/streaming` returns only streaming
- `/api/search` still works (backward compatibility)

---

#### 2.2 Update SimpleSearch to Support Filtering

**File:** `karma_player/services/simple_search.py`

- [ ] Add `source_type_filter: Optional[str]` parameter
- [ ] Pass filter to SearchEngine
- [ ] Update SearchEngine to filter adapters by type
- [ ] Test filtering logic

**Code Snippet:**
```python
async def search(
    self,
    query: str,
    format_filter: Optional[str] = None,
    min_seeders: int = 1,
    limit: int = 20,
    source_type_filter: Optional[str] = None,  # NEW: "torrent", "streaming", or None (all)
    progress_callback: Optional[Callable] = None
) -> SimpleSearchResult:
    """Execute simple search with optional source type filtering"""
    # ... existing parsing logic ...

    # Search with source type filter
    torrents = await self.search_engine.search(
        query=search_str,
        format_filter=music_query.format,
        min_seeders=music_query.min_seeders,
        source_type_filter=source_type_filter  # Pass filter
    )

    # ... rest of logic ...
```

**File:** `karma_player/services/search/engine.py`

```python
async def search(
    self,
    query: str,
    format_filter: Optional[str] = None,
    min_seeders: int = 5,
    timeout_per_adapter: float = 8.0,
    source_type_filter: Optional[str] = None,  # NEW
) -> List[MusicSource]:
    """Search with optional source type filtering"""
    # Filter adapters by health AND source type
    healthy_adapters = [a for a in self.adapters if a.is_healthy]

    # Further filter by source type if specified
    if source_type_filter == "torrent":
        healthy_adapters = [
            a for a in healthy_adapters
            if a.source_type == SourceType.TORRENT
        ]
    elif source_type_filter == "streaming":
        healthy_adapters = [
            a for a in healthy_adapters
            if a.source_type in [SourceType.YOUTUBE, SourceType.PIPED, SourceType.INVIDIOUS]
        ]

    logger.info(f"🔍 Searching with {len(healthy_adapters)} adapters (filter: {source_type_filter})")

    # ... rest of logic unchanged ...
```

**Success Criteria:**
- `source_type_filter="torrent"` only uses Jackett adapter
- `source_type_filter="streaming"` only uses YouTube adapter
- No filter uses all adapters (backward compatibility)

---

#### 2.3 Update Flutter to Use Concurrent Searches

**File:** `gui/lib/screens/search_screen.dart`

- [ ] Create `_searchTorrents()` method
- [ ] Create `_searchStreaming()` method
- [ ] Update `_search()` to call both concurrently
- [ ] Merge results as they arrive
- [ ] Update UI to show progressive loading
- [ ] Add section headers (Stream Now / Download)

**Code Snippet:**
```dart
// New methods
Future<List<Map<String, dynamic>>> _searchTorrents() async {
  try {
    final response = await http.post(
      Uri.parse('${appSettings.searchApiUrl}/api/search/torrents'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'query': _searchController.text,
        'format_filter': null,
        'min_seeders': 1,
        'limit': 20,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    }
  } catch (e) {
    print('Torrent search error: $e');
  }
  return [];
}

Future<List<Map<String, dynamic>>> _searchStreaming() async {
  try {
    final response = await http.post(
      Uri.parse('${appSettings.searchApiUrl}/api/search/streaming'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'query': _searchController.text,
        'format_filter': null,
        'min_seeders': 1,
        'limit': 20,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    }
  } catch (e) {
    print('Streaming search error: $e');
  }
  return [];
}

// Updated main search method
void _search() async {
  if (_searchController.text.trim().isEmpty) return;

  setState(() {
    _isSearching = true;
    _progress = 0;
    _statusMessage = 'Searching...';
    _results = [];
  });

  try {
    // Fire both requests concurrently
    final results = await Future.wait([
      _searchStreaming(),  // Usually faster (1-2s)
      _searchTorrents(),   // Usually slower (5-10s)
    ]);

    final streamingResults = results[0];
    final torrentResults = results[1];

    setState(() {
      // Combine results (streaming first for better UX)
      _results = [...streamingResults, ...torrentResults];
      _applyFilter();
      _statusMessage = 'Found ${_filteredResults.length} results';
      _isSearching = false;
    });
  } catch (e, stackTrace) {
    AnalyticsService().captureError(
      e,
      stackTrace,
      context: 'concurrent_search',
      extras: {'query': _searchController.text},
    );

    setState(() {
      _statusMessage = 'Search error: $e';
      _isSearching = false;
    });
  }
}
```

**Success Criteria:**
- Both searches fire simultaneously
- Streaming results appear first (1-2s)
- Torrent results appear after (5-10s)
- User can interact with streaming results while torrents load

---

#### 2.4 Add Section-Based UI

**File:** `gui/lib/screens/search_screen.dart`

- [ ] Create `_buildSectionHeader()` widget
- [ ] Separate results by source type
- [ ] Render "Stream Now" section first
- [ ] Render "Download (Torrents)" section second
- [ ] Update ListView to use sections

**Code Snippet:**
```dart
Widget _buildSectionHeader(String title, int count) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    child: Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    ),
  );
}

// In build() method, replace ListView.builder with:
Expanded(
  child: ListView(
    children: [
      // Streaming section (always on top for fast access)
      if (_streamingResults.isNotEmpty) ...[
        _buildSectionHeader('🎵 Stream Now', _streamingResults.length),
        ..._streamingResults.asMap().entries.map((entry) {
          return _buildResultCard(entry.key, entry.value);
        }),
        const SizedBox(height: 16),
      ],

      // Torrent section
      if (_torrentResults.isNotEmpty) ...[
        _buildSectionHeader('💾 Download (Torrents)', _torrentResults.length),
        ..._torrentResults.asMap().entries.map((entry) {
          return _buildResultCard(entry.key, entry.value);
        }),
      ],

      // No results
      if (_streamingResults.isEmpty && _torrentResults.isEmpty && !_isSearching) ...[
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No results found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    ],
  ),
)
```

- [ ] Add `_streamingResults` and `_torrentResults` fields
- [ ] Update `_applyFilter()` to separate by type
- [ ] Test section rendering

**Success Criteria:**
- Streaming results shown in dedicated section
- Torrent results shown in separate section
- Sections have clear headers with counts
- Better visual hierarchy

---

### Phase 2 Testing Checklist

- [ ] Test `/api/search/torrents` endpoint (Postman/curl)
- [ ] Test `/api/search/streaming` endpoint (Postman/curl)
- [ ] Test concurrent searches in Flutter app
- [ ] Verify streaming results appear first
- [ ] Verify torrent results appear after
- [ ] Test with filter chips (All/Torrents/Streaming)
- [ ] Test backward compatibility with `/api/search`
- [ ] Run `flutter analyze` - no errors
- [ ] Performance test: Measure time-to-first-result
- [ ] Commit: "Phase 2: Decouple torrent and streaming searches"

**Expected Results:**
- ⚡ 60% reduction in perceived latency
- 🎯 Independent source failures don't block each other
- 🎨 Better UX with sectioned results

---

## Phase 3: Result Streaming (5-7 days)

**Goal:** Implement real-time progressive result loading via WebSocket.

### Checklist

#### 3.1 Enhance WebSocket Backend

**File:** `karma_player/api/search_api.py`

The WebSocket endpoint already exists (line 340)! We need to enhance it:

- [ ] Add per-adapter progress updates
- [ ] Send partial results as each adapter completes
- [ ] Add error handling per adapter
- [ ] Test WebSocket with multiple clients

**Code Snippet:**
```python
@app.websocket("/ws/search")
async def websocket_search(websocket: WebSocket):
    """Enhanced WebSocket with progressive results"""
    await websocket.accept()
    logger.info("WebSocket connection established")

    try:
        data = await websocket.receive_text()
        request_data = json.loads(data)

        query = request_data.get("query")
        format_filter = request_data.get("format_filter")
        min_seeders = request_data.get("min_seeders", 1)
        limit = request_data.get("limit", 20)
        source_filter = request_data.get("source_filter")  # NEW: optional filter

        if not query:
            await websocket.send_json({
                "type": "error",
                "message": "Query is required"
            })
            await websocket.close()
            return

        logger.info(f"WebSocket search: {query} (filter: {source_filter})")

        # Progress callback with per-adapter updates
        adapter_results = {}

        async def send_progress(percent: int, message: str):
            await websocket.send_json({
                "type": "progress",
                "percent": percent,
                "message": message
            })

        # NEW: Send partial results as each adapter completes
        async def send_partial_result(adapter_name: str, sources: List[MusicSource]):
            """Send results from one adapter immediately"""
            ranked = []
            for i, source in enumerate(sources, 1):
                ranked.append({
                    "rank": i,
                    "source": source.to_dict(),
                    "explanation": _generate_explanation(source),
                    "tags": _generate_tags(source),
                })

            await websocket.send_json({
                "type": "partial_result",
                "adapter": adapter_name,
                "count": len(ranked),
                "results": ranked
            })

            adapter_results[adapter_name] = sources

        # Execute search with progressive callback
        result = await search_service.search(
            query=query,
            format_filter=format_filter,
            min_seeders=min_seeders,
            limit=limit,
            source_type_filter=source_filter,
            progress_callback=send_progress,
            partial_result_callback=send_partial_result  # NEW
        )

        # Send final complete signal
        await websocket.send_json({
            "type": "complete",
            "total_found": result.total_found,
            "search_time_ms": result.search_time_ms,
            "adapters_used": list(adapter_results.keys())
        })

        logger.info(f"WebSocket search completed: {result.total_found} results")

    except WebSocketDisconnect:
        logger.info("WebSocket disconnected")
    except Exception as e:
        logger.error(f"WebSocket error: {e}", exc_info=True)
        await websocket.send_json({
            "type": "error",
            "message": str(e)
        })
    finally:
        await websocket.close()
```

**Success Criteria:**
- WebSocket sends progress updates during search
- Partial results sent as each adapter completes
- Complete signal sent when all adapters finish
- Multiple concurrent WebSocket connections supported

---

#### 3.2 Update SearchEngine for Progressive Results

**File:** `karma_player/services/search/engine.py`

- [ ] Add `partial_result_callback` parameter
- [ ] Call callback as each adapter completes
- [ ] Don't wait for all adapters before sending results

**Code Snippet:**
```python
from typing import Callable, Awaitable

async def search(
    self,
    query: str,
    format_filter: Optional[str] = None,
    min_seeders: int = 5,
    timeout_per_adapter: float = 8.0,
    source_type_filter: Optional[str] = None,
    partial_result_callback: Optional[Callable[[str, List[MusicSource]], Awaitable[None]]] = None,  # NEW
) -> List[MusicSource]:
    """Search with progressive result streaming"""
    healthy_adapters = [a for a in self.adapters if a.is_healthy]
    # ... filtering logic ...

    # Search with progressive callbacks
    async def search_adapter(adapter: SourceAdapter):
        try:
            results = await asyncio.wait_for(
                adapter.search(query),
                timeout=timeout_per_adapter
            )

            # Send partial results immediately
            if partial_result_callback and results:
                await partial_result_callback(adapter.name, results)

            adapter._update_health(success=True)
            return results

        except asyncio.TimeoutError:
            logger.warning(f"⏱️  {adapter.name} timed out")
            adapter._update_health(success=False)
            return []

    # Execute all searches (results stream as they complete)
    tasks = [search_adapter(adapter) for adapter in healthy_adapters]
    results_lists = await asyncio.gather(*tasks, return_exceptions=True)

    # Combine all results
    all_results = []
    for results in results_lists:
        if not isinstance(results, Exception):
            all_results.extend(results)

    # Deduplicate, filter, sort (existing logic)
    # ...

    return filtered_results
```

**Success Criteria:**
- Callback invoked as each adapter completes
- Faster adapters (YouTube) send results immediately
- Slower adapters (Jackett) don't block fast results

---

#### 3.3 Implement WebSocket in Flutter

**File:** `gui/lib/screens/search_screen.dart`

- [ ] Add WebSocket search method
- [ ] Handle progress messages
- [ ] Handle partial result messages
- [ ] Handle complete message
- [ ] Update UI progressively
- [ ] Add connection error handling
- [ ] Implement reconnection logic

**Code Snippet:**
```dart
import 'package:web_socket_channel/web_socket_channel.dart';

// Add field
WebSocketChannel? _wsChannel;
bool _useWebSocket = true;  // Feature flag

void _searchWebSocket() async {
  if (_searchController.text.trim().isEmpty) return;

  setState(() {
    _isSearching = true;
    _progress = 0;
    _statusMessage = 'Connecting...';
    _results = [];
    _streamingResults = [];
    _torrentResults = [];
  });

  try {
    // Connect to WebSocket
    final wsUrl = appSettings.searchApiUrl.replaceFirst('http', 'ws');
    _wsChannel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/ws/search')
    );

    // Send search request
    _wsChannel!.sink.add(json.encode({
      'query': _searchController.text,
      'format_filter': null,
      'min_seeders': 1,
      'limit': 20,
      'source_filter': _sourceFilter == SourceFilter.all
          ? null
          : _sourceFilter.name,
    }));

    // Listen for messages
    _wsChannel!.stream.listen(
      (message) {
        final data = json.decode(message);

        switch (data['type']) {
          case 'progress':
            setState(() {
              _progress = data['percent'] ?? 0;
              _statusMessage = data['message'] ?? 'Searching...';
            });
            break;

          case 'partial_result':
            // Add partial results as they arrive
            final newResults = List<Map<String, dynamic>>.from(
              data['results'] ?? []
            );

            setState(() {
              _results.addAll(newResults);
              _separateResultsByType();  // Split into streaming/torrent
              _statusMessage = 'Found ${_results.length} results from ${data["adapter"]}...';
            });
            break;

          case 'complete':
            setState(() {
              _isSearching = false;
              _progress = 100;
              _statusMessage = 'Found ${_results.length} results in ${data["search_time_ms"]}ms';
            });
            _wsChannel?.sink.close();
            _wsChannel = null;
            break;

          case 'error':
            setState(() {
              _statusMessage = 'Error: ${data["message"]}';
              _isSearching = false;
            });
            _wsChannel?.sink.close();
            _wsChannel = null;
            break;
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        setState(() {
          _statusMessage = 'Connection error: $error';
          _isSearching = false;
        });
      },
      onDone: () {
        print('WebSocket closed');
        if (_isSearching) {
          setState(() {
            _statusMessage = 'Connection closed';
            _isSearching = false;
          });
        }
      },
    );
  } catch (e, stackTrace) {
    AnalyticsService().captureError(
      e,
      stackTrace,
      context: 'websocket_search',
      extras: {'query': _searchController.text},
    );

    setState(() {
      _statusMessage = 'Connection error: $e';
      _isSearching = false;
    });
  }
}

void _separateResultsByType() {
  _streamingResults = _results.where((r) {
    final source = r['source'] ?? r['torrent'];
    final type = source['source_type'] ?? 'torrent';
    return type == 'youtube' || type == 'piped';
  }).toList();

  _torrentResults = _results.where((r) {
    final source = r['source'] ?? r['torrent'];
    final type = source['source_type'] ?? 'torrent';
    return type == 'torrent';
  }).toList();
}

// Update main search method to use WebSocket
void _search() {
  if (_useWebSocket) {
    _searchWebSocket();
  } else {
    _searchHTTP();  // Fallback to Phase 2 implementation
  }
}
```

**Success Criteria:**
- WebSocket connection established on search
- Progress bar updates in real-time
- Streaming results appear first (1-2s)
- Torrent results appear progressively (5-10s)
- Connection errors handled gracefully
- Fallback to HTTP if WebSocket unavailable

---

#### 3.4 Add Loading States per Section

**File:** `gui/lib/screens/search_screen.dart`

- [ ] Add `_streamingLoading` and `_torrentLoading` booleans
- [ ] Show section skeletons while loading
- [ ] Update sections as results arrive
- [ ] Show "Loading..." indicators per section

**Code Snippet:**
```dart
// Add fields
bool _streamingLoading = false;
bool _torrentLoading = false;

// In WebSocket listener:
case 'partial_result':
  final adapterName = data['adapter'] as String;
  final newResults = List<Map<String, dynamic>>.from(data['results'] ?? []);

  setState(() {
    _results.addAll(newResults);
    _separateResultsByType();

    // Update loading state based on adapter
    if (adapterName.toLowerCase().contains('youtube')) {
      _streamingLoading = false;
    } else if (adapterName.toLowerCase().contains('jackett')) {
      _torrentLoading = false;
    }
  });
  break;

// In build() - add loading indicators
if (_streamingLoading) ...[
  _buildSectionHeader('🎵 Stream Now', 0),
  const Padding(
    padding: EdgeInsets.all(16),
    child: Center(
      child: CircularProgressIndicator(),
    ),
  ),
],

if (_streamingResults.isNotEmpty) ...[
  _buildSectionHeader('🎵 Stream Now', _streamingResults.length),
  ..._streamingResults.asMap().entries.map((e) => _buildResultCard(e.key, e.value)),
],
```

**Success Criteria:**
- Section shows loading spinner until results arrive
- Spinner replaced with results when adapter completes
- No jank or UI jumping during updates

---

### Phase 3 Testing Checklist

- [ ] Test WebSocket connection establishment
- [ ] Test progress updates in real-time
- [ ] Test partial results appearing progressively
- [ ] Test complete signal and cleanup
- [ ] Test connection errors and reconnection
- [ ] Test fallback to HTTP if WebSocket unavailable
- [ ] Test multiple concurrent searches (cancel previous)
- [ ] Performance test: Measure time-to-first-result
- [ ] Load test: Multiple concurrent WebSocket connections
- [ ] Run `flutter analyze` - no errors
- [ ] Commit: "Phase 3: WebSocket streaming with progressive results"

**Expected Results:**
- ⚡ 80% reduction in perceived latency
- 🚀 Results appear as each adapter completes
- 💫 Smooth progressive loading animation
- 🎯 Better UX with real-time feedback

---

## Phase 4: Optimization & Scalability (7-10 days)

**Goal:** Add caching, pagination, rate limiting for production readiness.

### Checklist

#### 4.1 Add Redis Caching

**Files:**
- `karma_player/services/cache.py` (NEW)
- `karma_player/api/search_api.py`
- `requirements.txt` or `pyproject.toml`

- [ ] Add Redis to dependencies: `redis>=5.0.0`
- [ ] Create `CacheService` class
- [ ] Add cache layer to search pipeline
- [ ] Implement cache key generation
- [ ] Add cache TTL (1 hour for results, 24h for queries)
- [ ] Add cache statistics logging
- [ ] Test cache hit/miss behavior

**New File: `karma_player/services/cache.py`**
```python
"""Result caching service using Redis"""
import json
import hashlib
import logging
from typing import Optional
from redis import Redis
from redis.exceptions import RedisError

from karma_player.config import config

logger = logging.getLogger(__name__)


class CacheService:
    """Redis-based caching for search results"""

    def __init__(self):
        try:
            self.redis = Redis(
                host=config.REDIS_HOST or 'localhost',
                port=config.REDIS_PORT or 6379,
                db=0,
                decode_responses=True,
                socket_timeout=2,
            )
            # Test connection
            self.redis.ping()
            self.enabled = True
            logger.info("✅ Redis cache enabled")
        except RedisError as e:
            logger.warning(f"⚠️  Redis unavailable, caching disabled: {e}")
            self.enabled = False

    def _generate_key(self, query: str, **params) -> str:
        """Generate cache key from query and parameters"""
        # Normalize query (lowercase, strip)
        normalized_query = query.lower().strip()

        # Sort params for consistent keys
        param_str = json.dumps(params, sort_keys=True)

        # Hash for compact key
        key_data = f"{normalized_query}:{param_str}"
        key_hash = hashlib.md5(key_data.encode()).hexdigest()

        return f"search:{key_hash}"

    def get(self, query: str, **params) -> Optional[dict]:
        """Get cached search result"""
        if not self.enabled:
            return None

        try:
            key = self._generate_key(query, **params)
            cached = self.redis.get(key)

            if cached:
                logger.info(f"💾 Cache HIT: '{query[:30]}...'")
                return json.loads(cached)
            else:
                logger.info(f"🔍 Cache MISS: '{query[:30]}...'")
                return None

        except RedisError as e:
            logger.error(f"Cache read error: {e}")
            return None

    def set(self, query: str, result: dict, ttl: int = 3600, **params):
        """Store search result in cache"""
        if not self.enabled:
            return

        try:
            key = self._generate_key(query, **params)
            self.redis.setex(
                key,
                ttl,  # 1 hour default
                json.dumps(result)
            )
            logger.info(f"💾 Cached result for '{query[:30]}...' (TTL: {ttl}s)")

        except RedisError as e:
            logger.error(f"Cache write error: {e}")

    def invalidate(self, pattern: str = "search:*"):
        """Invalidate cache entries by pattern"""
        if not self.enabled:
            return

        try:
            keys = self.redis.keys(pattern)
            if keys:
                self.redis.delete(*keys)
                logger.info(f"🗑️  Invalidated {len(keys)} cache entries")
        except RedisError as e:
            logger.error(f"Cache invalidation error: {e}")


# Global cache instance
cache_service = CacheService()
```

**Update `search_api.py`:**
```python
from karma_player.services.cache import cache_service

@app.post("/api/search", response_model=SearchResponse)
async def search(request: SearchRequest):
    """Search with caching"""
    if not search_service:
        raise HTTPException(status_code=503, detail="Search service not initialized")

    logger.info(f"Search request: {request.query}")

    # Check cache
    cache_params = {
        'format_filter': request.format_filter,
        'min_seeders': request.min_seeders,
        'limit': request.limit,
    }

    cached_result = cache_service.get(request.query, **cache_params)
    if cached_result:
        return SearchResponse(**cached_result)

    # Cache miss - execute search
    result = await search_service.search(
        query=request.query,
        format_filter=request.format_filter,
        min_seeders=request.min_seeders,
        limit=request.limit
    )

    # Build response
    response_dict = _build_response_dict(result)

    # Store in cache (1 hour TTL)
    cache_service.set(request.query, response_dict, ttl=3600, **cache_params)

    return SearchResponse(**response_dict)
```

**Update `config.py`:**
```python
# Redis configuration
REDIS_HOST: str = os.getenv('REDIS_HOST', 'localhost')
REDIS_PORT: int = int(os.getenv('REDIS_PORT', '6379'))
```

**Success Criteria:**
- Redis connection established on startup
- Cache hit returns instant results
- Cache miss executes search and stores result
- 1-hour TTL for search results
- Graceful degradation if Redis unavailable

---

#### 4.2 Implement Pagination

**Backend:**
- [ ] Add `offset` parameter to SearchRequest
- [ ] Add `has_more` field to SearchResponse
- [ ] Return paginated results
- [ ] Keep full result set in cache for pagination

**Flutter:**
- [ ] Add `ScrollController` to ListView
- [ ] Detect scroll to bottom
- [ ] Load next page when near end
- [ ] Show loading indicator for pagination
- [ ] Prevent duplicate page loads

**Backend Changes (`search_api.py`):**
```python
class SearchRequest(BaseModel):
    query: str
    format_filter: Optional[str] = None
    min_seeders: int = 1
    limit: int = 20
    offset: int = 0  # NEW: Pagination offset


class SearchResponse(BaseModel):
    query: str
    sql_query: Optional[str]
    total_found: int
    search_time_ms: int
    results: List[RankedSource]
    has_more: bool  # NEW: Indicates if more results available
    offset: int  # NEW: Current offset


@app.post("/api/search", response_model=SearchResponse)
async def search(request: SearchRequest):
    """Search with pagination"""
    # ... cache check ...

    # Execute search (gets ALL results, then paginate)
    result = await search_service.search(
        query=request.query,
        format_filter=request.format_filter,
        min_seeders=request.min_seeders,
        limit=None,  # Get all results
    )

    # Paginate results
    all_results = result.results
    start = request.offset
    end = start + request.limit
    paginated = all_results[start:end]
    has_more = end < len(all_results)

    return SearchResponse(
        query=result.query,
        sql_query=result.sql_query,
        total_found=len(all_results),
        search_time_ms=result.search_time_ms,
        results=paginated,
        has_more=has_more,
        offset=request.offset,
    )
```

**Flutter Changes (`search_screen.dart`):**
```dart
// Add fields
final ScrollController _scrollController = ScrollController();
int _currentOffset = 0;
bool _hasMore = true;
bool _loadingMore = false;

@override
void initState() {
  super.initState();
  _scrollController.addListener(_onScroll);
  // ... rest of init ...
}

void _onScroll() {
  // Load more when 80% scrolled
  if (_scrollController.position.pixels >=
      _scrollController.position.maxScrollExtent * 0.8) {
    if (!_loadingMore && _hasMore && !_isSearching) {
      _loadMoreResults();
    }
  }
}

Future<void> _loadMoreResults() async {
  if (_loadingMore || !_hasMore) return;

  setState(() => _loadingMore = true);

  try {
    final response = await http.post(
      Uri.parse('${appSettings.searchApiUrl}/api/search'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'query': _searchController.text,
        'format_filter': null,
        'min_seeders': 1,
        'limit': 20,
        'offset': _currentOffset + 20,  // Next page
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final newResults = List<Map<String, dynamic>>.from(
        data['results'] ?? []
      );

      setState(() {
        _results.addAll(newResults);
        _applyFilter();
        _currentOffset += 20;
        _hasMore = data['has_more'] ?? false;
        _loadingMore = false;
      });
    }
  } catch (e) {
    print('Load more error: $e');
    setState(() => _loadingMore = false);
  }
}

// In ListView:
ListView(
  controller: _scrollController,  // Add controller
  children: [
    // ... sections ...

    // Loading indicator at bottom
    if (_loadingMore) ...[
      const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    ],
  ],
)

@override
void dispose() {
  _scrollController.dispose();
  // ... rest of dispose ...
}
```

**Success Criteria:**
- First search returns 20 results
- Scrolling to bottom loads next 20 results
- Loading indicator shown during pagination
- No duplicate results loaded
- Pagination works with filtering

---

#### 4.3 Add Rate Limiting

**File:** `karma_player/api/search_api.py`

- [ ] Install `slowapi`: `pip install slowapi`
- [ ] Add rate limiter middleware
- [ ] Configure limits (10 requests/minute per IP)
- [ ] Return 429 status on limit exceeded
- [ ] Add rate limit headers to responses

**Code Snippet:**
```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Create limiter
limiter = Limiter(key_func=get_remote_address)

# Add to FastAPI app
app = FastAPI(
    title="TrustTune Search API",
    description="AI-powered music search service",
    version=__version__,
    lifespan=lifespan
)

# Add limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Apply rate limits to endpoints
@app.post("/api/search", response_model=SearchResponse)
@limiter.limit("10/minute")  # 10 requests per minute per IP
async def search(request: SearchRequest, req: Request):
    """Search with rate limiting"""
    # ... existing logic ...


@app.post("/api/search/torrents", response_model=SearchResponse)
@limiter.limit("10/minute")
async def search_torrents(request: SearchRequest, req: Request):
    """Torrent search with rate limiting"""
    # ... existing logic ...


@app.post("/api/search/streaming", response_model=SearchResponse)
@limiter.limit("10/minute")
async def search_streaming(request: SearchRequest, req: Request):
    """Streaming search with rate limiting"""
    # ... existing logic ...
```

**Success Criteria:**
- 11th request in 1 minute returns 429 status
- Rate limit resets after 1 minute
- Headers show remaining requests
- Logged rate limit events

---

#### 4.4 Add Monitoring & Metrics

**File:** `karma_player/services/metrics.py` (NEW)

- [ ] Add Prometheus metrics
- [ ] Track search latency
- [ ] Track cache hit rate
- [ ] Track adapter health
- [ ] Track API usage per endpoint
- [ ] Create `/metrics` endpoint

**Code Snippet:**
```python
"""Prometheus metrics for monitoring"""
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from fastapi import Response

# Define metrics
search_requests_total = Counter(
    'search_requests_total',
    'Total search requests',
    ['endpoint', 'status']
)

search_latency_seconds = Histogram(
    'search_latency_seconds',
    'Search request latency',
    ['endpoint']
)

cache_hits_total = Counter(
    'cache_hits_total',
    'Total cache hits',
    ['hit']
)

adapter_health = Gauge(
    'adapter_health',
    'Adapter health status (1=healthy, 0=unhealthy)',
    ['adapter']
)

# Add to search_api.py
from karma_player.services.metrics import (
    search_requests_total,
    search_latency_seconds,
    cache_hits_total,
)

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(
        content=generate_latest(),
        media_type="text/plain"
    )

# Instrument endpoints
@app.post("/api/search", response_model=SearchResponse)
async def search(request: SearchRequest):
    with search_latency_seconds.labels(endpoint='search').time():
        try:
            # Check cache
            cached = cache_service.get(request.query)
            if cached:
                cache_hits_total.labels(hit='true').inc()
                return cached
            else:
                cache_hits_total.labels(hit='false').inc()

            # Execute search
            result = await search_service.search(...)

            search_requests_total.labels(endpoint='search', status='success').inc()
            return result

        except Exception as e:
            search_requests_total.labels(endpoint='search', status='error').inc()
            raise
```

**Success Criteria:**
- `/metrics` endpoint returns Prometheus format
- Metrics updated on each request
- Grafana dashboard can visualize metrics
- Alerts configured for high error rate

---

### Phase 4 Testing Checklist

- [ ] Test Redis connection and caching
- [ ] Test cache hit returns instant results
- [ ] Test pagination - scroll to load more
- [ ] Test rate limiting - 11th request blocked
- [ ] Test metrics endpoint returns data
- [ ] Load test: 100 concurrent requests
- [ ] Stress test: 1000 requests with rate limiting
- [ ] Monitor cache hit rate over 1 hour
- [ ] Test graceful degradation (Redis down)
- [ ] Run security scan (OWASP ZAP)
- [ ] Run `flutter analyze` - no errors
- [ ] Performance test: Compare Phase 0 vs Phase 4
- [ ] Commit: "Phase 4: Caching, pagination, rate limiting, monitoring"

**Expected Results:**
- ⚡ 10x faster for cached queries (<100ms)
- 💰 80% reduction in API calls
- 🛡️ Protected against abuse (rate limiting)
- 📊 Full observability (metrics + logs)
- 🚀 Production-ready scalability

---

## Testing Strategy

### Unit Tests

**Backend:**
```bash
# Run all tests
poetry run pytest

# Run with coverage
poetry run pytest --cov=karma_player --cov-report=html

# Run specific test file
poetry run pytest tests/test_search_engine.py -v
```

**Flutter:**
```bash
# Run all tests
flutter test

# Run specific test
flutter test test/search_screen_test.dart

# Run with coverage
flutter test --coverage
```

### Integration Tests

**Backend API:**
```bash
# Test endpoints with curl
curl -X POST http://localhost:3000/api/search \
  -H "Content-Type: application/json" \
  -d '{"query": "radiohead", "limit": 5}'

# Test WebSocket
wscat -c ws://localhost:3000/ws/search
> {"query": "radiohead", "limit": 5}
```

**Flutter:**
```bash
# Integration tests
flutter test integration_test/search_flow_test.dart

# Run on device
flutter test integration_test --device-id <device-id>
```

### Performance Tests

**Load Testing (k6):**
```javascript
// load_test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 10,  // 10 virtual users
  duration: '30s',
};

export default function () {
  const payload = JSON.stringify({
    query: 'radiohead',
    limit: 20,
  });

  const res = http.post('http://localhost:3000/api/search', payload, {
    headers: { 'Content-Type': 'application/json' },
  });

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 5s': (r) => r.timings.duration < 5000,
  });

  sleep(1);
}
```

Run: `k6 run load_test.js`

### Manual Testing Checklist

**Phase 1:**
- [ ] Search "radiohead" - verify NO OpenAI API call in backend logs
- [ ] Verify logs show "Direct pass-through (no AI)"
- [ ] Disable Jackett or simulate slow response - verify 8s timeout handling
- [ ] Verify only 20 results returned (check result count in UI)
- [ ] Test `/api/search/advanced` endpoint - verify AI parsing works for power users

**Phase 2:**
- [ ] Search - verify streaming results appear first
- [ ] Search - verify torrent results appear after
- [ ] Filter by Torrents - verify only torrents shown
- [ ] Filter by Streaming - verify only streaming shown

**Phase 3:**
- [ ] Search - verify progress bar updates in real-time
- [ ] Search - verify partial results appear progressively
- [ ] Disconnect network during search - verify error handling
- [ ] Reconnect - verify search works again

**Phase 4:**
- [ ] Search popular query - verify cached response is instant
- [ ] Scroll to bottom - verify pagination loads more
- [ ] Make 11 requests in 1 minute - verify rate limiting
- [ ] Check `/metrics` endpoint - verify data present

---

## Rollback Plan

### If Phase 1 Fails
- Revert commits: `git revert <commit-hash>`
- Remove debouncing: Restore original `TextField.onSubmitted`
- Remove cache: Comment out caching logic
- Remove timeouts: Restore original `asyncio.gather`

### If Phase 2 Fails
- Use `/api/search` endpoint (legacy)
- Revert Flutter to single HTTP POST
- Keep backend split endpoints for future use

### If Phase 3 Fails
- Fallback to Phase 2 HTTP implementation
- Add feature flag: `_useWebSocket = false`
- Keep WebSocket backend for future use

### If Phase 4 Fails
- Disable Redis caching: `cache_service.enabled = False`
- Remove pagination: Use original limit-based approach
- Remove rate limiting: Comment out `@limiter.limit()` decorators

### Emergency Rollback (Production)
```bash
# Backend
git checkout main
git pull origin main
poetry install
systemctl restart karma-player-api

# Flutter (re-release)
git checkout main
git pull origin main
flutter clean
flutter pub get
flutter build <platform>
```

---

## Progress Tracking

### Phase Status

| Phase | Status | Start Date | Completion Date | Notes |
|-------|--------|------------|-----------------|-------|
| Phase 1 | 🔲 Not Started | - | - | - |
| Phase 2 | 🔲 Not Started | - | - | - |
| Phase 3 | 🔲 Not Started | - | - | - |
| Phase 4 | 🔲 Not Started | - | - | - |

**Legend:**
- 🔲 Not Started
- 🟡 In Progress
- ✅ Completed
- ❌ Blocked

### Current Blockers

_None_

### Notes & Decisions

_Add implementation notes here as you progress_

---

## References

- **Architecture Analysis:** See detailed report in project documentation
- **Backend Code:** `karma_player/api/search_api.py`, `karma_player/services/simple_search.py`
- **Frontend Code:** `gui/lib/screens/search_screen.dart`
- **WebSocket Docs:** https://docs.python.org/3/library/asyncio-task.html
- **Flutter WebSocket:** https://pub.dev/packages/web_socket_channel
- **Redis Python:** https://redis-py.readthedocs.io/
- **Prometheus:** https://prometheus.io/docs/introduction/overview/

---

**Document Version:** 1.0
**Last Updated:** 2025-11-05
**Owner:** Development Team
