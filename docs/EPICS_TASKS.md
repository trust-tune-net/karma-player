# Phase 0: Core Validation

**Timeline:** Weeks 1-2
**Goal:** Prove people can use the basic flow
**No network, no AI, no validation - just the pipeline**

---

## Epic 1: Project Setup

### Task 1.1: Initialize CLI Project
**Description:** Set up Python CLI framework
**Tech:** Click or Typer framework, Poetry for deps
**DoD:**
- `music-agent --version` works
- `music-agent --help` shows commands
- Project structure established
- README with setup instructions

**Tests:**
- Unit test: CLI imports successfully
- Integration: `--help` returns expected text

---

### Task 1.2: Configuration Management
**Description:** Store user config locally
**Tech:** SQLite + config file (~/.music-agent/)
**DoD:**
- `music-agent init` creates ~/.music-agent/ directory
- Stores: MusicBrainz API key, music directory path, user ID (generated locally)
- `music-agent config show` displays current config
- Config validation (check API key works)

**Tests:**
- Unit: Config reads/writes correctly
- Integration: Init command creates valid config
- E2E: Invalid API key shows helpful error

---

## Epic 2: Search Flow

user;aroudo
pass;iO_0+.g8OR@$

### Task 2.1: MusicBrainz Integration
**Description:** Query MusicBrainz API for canonical metadata
**DoD:**
- `music-agent search "radiohead paranoid android"` queries MusicBrainz
- Returns structured results: MBID, artist, title, album, year, duration
- Handles rate limiting (1 req/sec)
- Uses user's API key from config
- Displays max 10 results

**Tests:**
- Unit: MusicBrainz API client with mocked responses
- Integration: Real API query (use VCR for recording)
- E2E: Search "beatles yesterday" returns expected MBID

**Edge cases:**
- No results found
- Multiple matches (let user pick)
- API timeout/error
- Rate limit exceeded

---

### Task 2.2: User Selection Interface
**Description:** Let user pick which result they want
**DoD:**
- Display results numbered [1], [2], [3]...
- User types number to select
- Validation: rejects invalid input
- Option to quit (q)

**Tests:**
- Unit: Selection parser
- E2E: User picks option 2, gets correct MBID

---

## Epic 3: Torrent Search (refer to docs/EPIC_3.md)

### Task 3.1: Torrent Indexer Integration
**Description:** Search 2-3 public torrent sites
**Indexers:** 1337x, Pirate Bay, Rutracker (if accessible)
**DoD:**
- Query indexers with artist + title from MusicBrainz
- Parse responses: name, hash, seeders, size, format (inferred from filename)
- Return 5-10 best candidates (sorted by seeders)
- Handle errors gracefully (site down, timeout)

**Tests:**
- Unit: Parser for each indexer HTML/API
- Integration: Mocked HTTP responses
- E2E: Search "aphex twin" returns torrents with >0 seeders

**Edge cases:**
- Indexer offline (skip it, continue)
- No results (show message)
- Parsing errors (log, skip result)

---

### Task 3.2: Result Display & Selection
**Description:** Show torrent options to user
**DoD:**
- Display format: [A] filename | Format | Size | Seeders
- Infer format from filename (FLAC/MP3/etc)
- Color coding (if terminal supports): green for FLAC, yellow for MP3
- User selects with letter (A, B, C...)
- Option to see more results or quit

**Tests:**
- Unit: Format inference from filenames
- E2E: User sees results and can select one

---

## Epic 4: Download Manager

### Task 4.1: BitTorrent Integration
**Description:** Download selected torrent
**Tech:** libtorrent-python or qbittorrent-api
**DoD:**
- `music-agent download [hash]` starts download
- Progress bar shows: % complete, speed, ETA
- Saves to configured music directory
- Auto-creates folder structure: ~/Music/[Artist]/[Album]/
- Starts seeding automatically after completion

**Tests:**
- Integration: Download small test torrent (public domain)
- E2E: Complete download saves file to correct path

**Edge cases:**
- Download fails (no seeders)
- Disk space full
- Permission errors
- User cancels (Ctrl+C)

---

### Task 4.2: Local Database Tracking
**Description:** Track downloads in SQLite
**Schema:**
```
downloads:
  id (UUID)
  mbid (string)
  torrent_hash (string)
  filename (string)
  file_path (string)
  size_bytes (int)
  downloaded_at (timestamp)
  is_seeding (boolean)
  seeders_count (int)
```

**DoD:**
- Every download recorded
- Can query: "show my downloads"
- Can query: "what am I seeding?"

**Tests:**
- Unit: Database CRUD operations
- Integration: Download creates database entry

---

## Epic 5: Voting (Local Only)

### Task 5.1: Vote Interface
**Description:** Let users upvote/downvote files
**DoD:**
- After download completes, prompt: "Did you get the correct song? [↑] Upvote [↓] Downvote [s] Skip"
- Store vote locally in SQLite
- Can vote later: `music-agent vote [hash] up/down`
- View vote history: `music-agent votes`

**Schema:**
```
votes:
  id (UUID)
  mbid (string)
  torrent_hash (string)
  vote (int: +1 or -1)
  voted_at (timestamp)
  comment (string, optional)
```

**Tests:**
- Unit: Vote storage/retrieval
- E2E: Complete download → vote → stored correctly

**Notes:** Votes are LOCAL ONLY in Phase 0. No network sync yet.

---

## Epic 6: Stats & Status

### Task 6.1: Stats Dashboard
**Description:** Show user their activity
**DoD:**
- `music-agent stats` displays:
  - Total downloads
  - Currently seeding (# of files)
  - Total uploaded (bytes)
  - Votes cast
  - Karma (hardcoded to 0 for Phase 0)

**Tests:**
- E2E: After 3 downloads, stats show 3

---

### Task 6.2: Seeding Monitor
**Description:** Track seeding status
**DoD:**
- `music-agent seeding` shows active torrents
- Display: filename, uploaded bytes, ratio, seeders
- Auto-start seeding on app launch
- Background daemon (or instructions to run manually)

**Tests:**
- Integration: Seeding status reflects libtorrent state

---

## Epic 7: Error Handling & UX

### Task 7.1: Friendly Error Messages
**Description:** All errors are human-readable
**DoD:**
- No stack traces shown to users (log them)
- Specific messages: "MusicBrainz API key invalid", "No seeders found", etc.
- Suggestions: "Try searching with album name"

**Tests:**
- E2E: Trigger each error type, verify message

---

### Task 7.2: Help & Documentation
**Description:** Built-in help
**DoD:**
- `music-agent --help` shows all commands
- `music-agent search --help` shows search options
- README with:
  - Installation instructions
  - Getting MusicBrainz API key
  - Example usage
  - Troubleshooting

---

## Testing Strategy

### Unit Tests (70% coverage minimum)
- All parsers (MusicBrainz, torrent indexers)
- Database operations
- Format inference logic
- Configuration validation

### Integration Tests
- MusicBrainz API (with recorded responses)
- Torrent search (mocked HTTP)
- Database persistence
- Libtorrent integration

### End-to-End Tests (Critical Paths)
1. **Happy path:** Search → Select → Download → Vote
2. **No results:** Search for nonsense → Friendly error
3. **Multiple results:** Search common artist → Pick from list
4. **Failed download:** Select dead torrent → Error handling

### Manual Testing Scenarios
- Run on fresh machine (test setup instructions)
- Try with real MusicBrainz API
- Download actual torrent (use public domain music)
- Check file saved in correct location
- Verify seeding starts

---

## Definition of Done (Phase 0)

### Functional Requirements ✅
- [ ] User can initialize config with API keys
- [ ] User can search MusicBrainz by artist/song
- [ ] User can select from multiple results
- [ ] User can search torrents for selected MBID
- [ ] User can select torrent to download
- [ ] Download shows progress bar
- [ ] File saves to correct directory structure
- [ ] Seeding starts automatically
- [ ] User can vote on downloaded files
- [ ] User can view stats and seeding status
- [ ] All commands have `--help` text

### Non-Functional Requirements ✅
- [ ] 70%+ unit test coverage
- [ ] All critical paths have E2E tests
- [ ] No crashes on invalid input
- [ ] Errors are user-friendly
- [ ] README with setup instructions
- [ ] Works on Mac, Linux, Windows (or document limitations)

### Quality Gates ✅
- [ ] 10 beta users successfully complete search → download → vote
- [ ] No critical bugs reported
- [ ] Average user completes first download in <5 minutes
- [ ] User feedback: "I understand what it does"

---

## Success Metrics (Week 2)

**Quantitative:**
- 10+ beta users onboarded
- 50+ total downloads across users
- 30+ votes cast
- 0 critical bugs

**Qualitative:**
- Users say: "This is easier than searching torrents manually"
- Feedback: "I want the verified network feature" (validates Phase 1)

---

## What We're NOT Building (Phase 0)

❌ Distributed network (Gun.js/Nostr/anything)
❌ Vote synchronization
❌ Community validation
❌ Karma system (just track locally)
❌ AI query parsing (basic string matching)
❌ Smart ranking (just sort by seeders)
❌ Badges/gamification
❌ Public profiles
❌ Any backend servers
❌ Web interface

---

## Tech Stack (Phase 0)

**Core:**
- Python 3.10+
- Click or Typer (CLI framework)
- SQLite (local storage)
- libtorrent or qbittorrent-api (torrents)

**APIs:**
- MusicBrainz API (metadata)
- Torrent indexer scraping (BeautifulSoup or API wrappers)

**Testing:**
- pytest
- pytest-vcr (record API responses)
- pytest-mock

**Distribution:**
- Poetry (dependency management)
- PyPI package (optional)
- Or just git clone + pip install

---

## Risk Mitigation

**Risk 1: MusicBrainz API rate limiting**
- Mitigation: Cache results aggressively, respect 1/sec limit
- Fallback: User provides their own API key (higher limits)

**Risk 2: Torrent indexers unreliable**
- Mitigation: Support 3+ indexers, graceful fallback
- Fallback: User can paste magnet link manually

**Risk 3: libtorrent complex/buggy**
- Mitigation: Test early, consider qbittorrent-api alternative
- Fallback: Generate magnet links, user opens in their client

**Risk 4: Users don't understand CLI**
- Mitigation: Excellent help text, clear errors, good README
- Fallback: Video tutorial

---

## Development Roadmap (2 weeks)

**Week 1:**
- Days 1-2: Project setup, MusicBrainz integration
- Days 3-4: Torrent search integration
- Days 5: Download manager

**Week 2:**
- Days 6-7: Voting interface, stats
- Days 8: Error handling, help text
- Days 9: Testing, bug fixes
- Day 10: Documentation, beta user onboarding

---

## Handoff to Phase 1

**Phase 0 Output:**
- Working CLI tool
- 10+ beta users with feedback
- Local database of downloads/votes
- Understanding of what works/doesn't

**Phase 1 Input:**
- Use local votes as seed data
- Beta users become first validators
- Proven UX patterns to maintain

**Question for Phase 1:**
- Centralized backend (PostgreSQL + API) or distributed (Nostr)?
- Decision based on Phase 0 learnings

---