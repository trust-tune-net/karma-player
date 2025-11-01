# YouTube Download Layer Analysis

## 1. Project Overview

**Purpose:** Enable streaming playback of YouTube Music content by downloading audio to temporary files for reliable playback in the Flutter desktop application.

**Main Goals:**
- Provide reliable YouTube Music playback (download-first approach avoids streaming unreliability)
- Handle YouTube's complexity (signatures, auth) via yt-dlp external tool
- Cross-platform support (macOS, Windows, Linux)

**Target Audience:** Users of TrustTune Network music player desktop app

**Primary Problems Solved:**
- Direct YouTube streaming unreliability → Download-first approach ensures 100% reliable playback
- YouTube API complexity → Offload all complexity to yt-dlp tool
- PATH issues on macOS → Bundled binary with system fallback prevents "No such file" errors

## 2. High-Level Architecture

```
User Search → YouTube Result → SearchScreen detects YouTube URL
    ↓
YouTubeDownloadService.downloadAudio(videoId)
    ↓
Check cache → If cached, return path
    ↓
Start yt-dlp process → Download to temp directory
    ↓
Parse progress → Find downloaded file
    ↓
Create Song object with local file path
    ↓
PlaybackService plays local file via media_kit
```

**Main Layers:**
1. **UI Layer** (SearchScreen): Detects YouTube URLs, triggers download
2. **Service Layer** (YouTubeDownloadService): Manages downloads, caching, process lifecycle
3. **Binary Layer** (yt-dlp): External process handles YouTube download complexity
4. **Storage Layer** (Temp Directory): Platform-specific temp storage with automatic cleanup
5. **Playback Layer** (PlaybackService): Media playback using local files

**Key Workflows:**
- **Download Flow:** videoId → cache check → yt-dlp process → temp file → Song creation → playback
- **Cancellation Flow:** New download cancels previous one (stream cleanup prevents SIGPIPE)
- **Cache Management:** Files cached by video ID, cleaned after 24 hours

## 3. Key Components

### 3.1 YouTubeDownloadService (`lib/services/youtube_download_service.dart`)

**Purpose:** Core service managing YouTube audio downloads

**Key State:**
- `_activeDownloads`: Map tracking ongoing downloads (prevents duplicates)
- `_activeProcesses`: Process handles for cancellation
- `_activeSubscriptions`: Stream subscriptions (prevents SIGPIPE crashes)
- `_currentDownloadId`: Currently downloading video

**Core Methods:**
- `downloadAudio(String videoId)`: Main entry point
  - Returns: `Future<String?>` (local file path or null)
  - Logic: Cache check → download → cancellation handling
  
- `_downloadAudioInternal(String videoId, int retryCount)`: Internal download logic
  - Retry support: Max 2 retries with 2s delay
  - Timeout: 5-minute timeout protection
  - Progress: Parses yt-dlp stdout for `[download] X%` messages
  
- `ytDlpPath` (getter): Binary path resolution
  - macOS: `Contents/Resources/bin/yt-dlp`
  - Windows: `{appDir}/yt-dlp.exe`
  - Linux: `{appDir}/bin/yt-dlp`
  - Fallback: System paths (Homebrew on macOS, `/usr/bin/yt-dlp` on Linux)

- `verifyYtDlp()`: Binary verification (runs `yt-dlp --version`)
- `cleanOldFiles(Duration maxAge)`: Cache cleanup (default 24h)
- `dispose()`: Cleanup all active downloads

### 3.2 SearchScreen Integration (`lib/screens/search_screen.dart`)

**Integration Point:** `_playStream()` method (lines 279-392)

**Flow:**
1. Detects YouTube URLs: `url.toString().contains('music.youtube.com')`
2. Shows download snackbar: "Downloading: {title}"
3. Calls `_youtubeDownloadService.downloadAudio(sourceId)`
4. Creates Song object with local file path
5. Passes to PlaybackService via `onSongTap` callback

**YouTube Detection Logic:**
```dart
if (url.toString().contains('music.youtube.com') && sourceId != null)
```

### 3.3 Song Model (`lib/models/song.dart`)

**YouTube-Specific Fields:**
- `filePath`: Local downloaded file path (temp directory)
- `httpHeaders`: Not used (null for downloaded files)
- `format`: Set to 'WEBM' for YouTube downloads
- `artist`: Hardcoded to 'YouTube Music'

**Creation Pattern:**
```dart
Song(
  id: sourceId,  // YouTube video ID
  title: title,
  artist: 'YouTube Music',
  filePath: filePath,  // Local temp file
  format: 'WEBM',
)
```

### 3.4 PlaybackService Integration (`lib/services/playback_service.dart`)

**Integration:** `playSong()` method (lines 169-275)

**How YouTube Files Play:**
- Opens local file via `Media(song.filePath)`
- No HTTP headers needed (local file)
- Uses media_kit's local file playback (100% reliable)

### 3.5 Analytics Integration (`lib/services/analytics_service.dart`)

**YouTube-Specific Tracking:**
- Breadcrumbs: Download start, yt-dlp execution, completion
- Error contexts: `youtube_download_*` tags
- Extras: video_id, url, exit_code, stderr

## 4. Data Flow

### 4.1 Download Flow

**Input:** YouTube video ID (from backend search API response)

**Process:**
1. Cache check: `_getCachedFile(videoId)` searches temp directory for `youtube_{videoId}.*`
2. If cached: Return existing file path immediately
3. If not cached: Start yt-dlp process
   - Command: `yt-dlp -f bestaudio --no-playlist --newline --no-warnings -o {template} {url}`
   - Output template: `youtube_%(id)s.%(ext)s`
   - URL: `https://music.youtube.com/watch?v={videoId}`
4. Progress monitoring: Parse stdout for `[download] X%` messages
5. Completion: Find downloaded file by pattern `youtube_{videoId}.*`
6. Output: Local file path string

### 4.2 File Storage

**Location:** Platform temp directory
- macOS/Linux: `/tmp`
- Windows: `%LOCALAPPDATA%\Temp`

**Naming Pattern:** `youtube_{videoId}.{ext}`
**Supported Extensions:** webm, opus, m4a, mp3, ogg (detected dynamically)
**Cleanup:** Files older than 24 hours deleted automatically (via `cleanOldFiles()`)

### 4.3 Data Models

- **Song Model:** Standard model, `filePath` points to temp file
- **No Special Schema:** Treats downloaded files same as library files
- **Metadata:** Limited (format='WEBM', artist='YouTube Music')

## 5. Dependencies & Integrations

### 5.1 Flutter Packages (`pubspec.yaml`)

**Direct Dependencies:**
- `path_provider: ^2.1.5`: Platform temp directory access
- `path: ^1.9.0`: Path manipulation utilities

**Indirect Dependencies:**
- `media_kit: ^1.1.11`: Media playback (via PlaybackService)
- `sentry_flutter: ^8.11.0`: Error tracking (via AnalyticsService)

### 5.2 External Binary: yt-dlp

**Purpose:** YouTube download engine (handles signatures, auth, format selection)

**Bundling Locations:**
- macOS: `KarmaPlayer.app/Contents/Resources/bin/yt-dlp`
- Windows: `{appDir}/yt-dlp.exe`
- Linux: `{appDir}/bin/yt-dlp`

**Fallback:** System installation
- macOS: Homebrew paths (`/opt/homebrew/bin/yt-dlp`, `/usr/local/bin/yt-dlp`)
- Linux: `/usr/bin/yt-dlp`

**Verification:** Runs `yt-dlp --version` on SearchScreen init

### 5.3 Integration Points

**Backend API** (`/api/search`):
- Provides YouTube search results with video IDs
- Source type: `source_type: 'youtube'`

**PlaybackService:**
- Receives Song objects with local file paths
- Uses media_kit Player to play files

**AnalyticsService:**
- Captures download errors, timeouts, verification failures
- Adds breadcrumbs for debugging

## 6. Configuration & Environment

### 6.1 Required Configuration

**yt-dlp Binary:**
- Must be present (bundled or system installation)
- Verified on SearchScreen init via `verifyYtDlp()`

**Temp Directory Access:**
- Requires write permissions (platform temp directories)

**Network Access:**
- Required for YouTube downloads

### 6.2 Environment Variables

None required (uses platform temp directories via `path_provider`)

### 6.3 Build Process

**macOS:** 
- `copy-resources.sh` script copies binaries to `Contents/Resources/bin/`
- Runs as Xcode build phase
- Fixes library paths for transmission-daemon (not yt-dlp)

**Windows/Linux:**
- Binaries copied during build process (CMakeLists.txt)

**Verification:**
- Binary check on SearchScreen `initState()` (non-blocking)

### 6.4 Installation

**Production:**
- App bundles yt-dlp binary (no user installation needed)

**Development:**
- Fallback to system installation (Homebrew on macOS)

## 7. Code Quality & Maintainability

### 7.1 Strengths

**Error Handling:**
- Comprehensive try/catch blocks with analytics reporting
- Specific error contexts (`youtube_download_*`) for debugging
- User-friendly error messages (full details in analytics)

**Resource Cleanup:**
- Proper disposal of processes and stream subscriptions
- Prevents SIGPIPE crashes on process termination
- `dispose()` method cleans up all active downloads

**Retry Logic:**
- Automatic retry on network errors (max 2 retries, 2s delay)
- Retry conditions: network, timeout, connection, rate limits (429, 503)

**Cache Management:**
- Avoids duplicate downloads (checks cache first)
- Tracks active downloads to prevent concurrent downloads of same video

**Cancellation Support:**
- Can cancel active downloads when new one starts
- Proper stream cleanup before process termination

### 7.2 Potential Issues

**Magic Numbers:**
- 24-hour cache default (hardcoded in `cleanOldFiles()`)
- 5-minute timeout (hardcoded in `_downloadAudioInternal()`)
- 2 retries maximum (hardcoded constant)

**Error Messages:**
- Generic messages to users ("Failed to download YouTube audio")
- Full details only in analytics (GlitchTip/Sentry)

**File Format Assumption:**
- Assumes yt-dlp uses expected naming pattern (`youtube_{id}.{ext}`)
- If yt-dlp changes format, file finding may fail

**Temp Directory Growth:**
- Only cleans on explicit call (`cleanOldFiles()`)
- No automatic background cleanup task

### 7.3 Technical Debt

**SIGPIPE Handling:**
- Complex stream subscription management
- Could be abstracted into helper class

**Process Management:**
- Manual tracking of processes, subscriptions, downloads
- Could use isolates for better isolation

**Cache Cleanup:**
- No automatic background cleanup (only on demand)
- Could add periodic cleanup task

**Error Recovery:**
- Limited retry conditions (only network/timeout errors)
- Could retry on file-not-found errors

## 8. Extensibility & Scalability

### 8.1 Easy Modifications

**Cache Duration:**
- Change `maxAge` parameter in `cleanOldFiles()` (currently 24h)

**Retry Count:**
- Modify `maxRetries` constant (currently 2)

**Timeout:**
- Adjust `timeoutDuration` (currently 5 minutes)

**Output Format:**
- Change yt-dlp `-f` flag (currently 'bestaudio')
- Could add user preference for audio quality

### 8.2 Scalability Considerations

**Concurrent Downloads:**
- Only one active download at a time (`_currentDownloadId`)
- Could support multiple concurrent downloads

**Cache Size:**
- No limit on cache size (only age-based cleanup)
- Could add size limit (e.g., max 1GB)

**Memory:**
- Process stdout/stderr streams held in memory during download
- Could stream to file instead

### 8.3 Improvement Suggestions

**Background Cleanup:**
- Periodic cache cleanup task (run on app startup)
- Monitor temp directory size

**Download Queue:**
- Support multiple concurrent downloads
- Queue management UI

**Format Selection:**
- User preference for audio quality (e.g., opus, m4a)
- Let user choose quality vs. file size tradeoff

**Persistent Cache:**
- Option to keep files longer than 24h
- User-configurable cache duration

**Progress Callbacks:**
- Real-time progress updates to UI
- Streaming progress events instead of stdout parsing

**Offline Support:**
- Check cache before attempting download
- Better offline error messages

## 9. Potential Risks & Considerations

### 9.1 Security Vulnerabilities

**Binary Execution:**
- yt-dlp runs with YouTube URLs (mitigated: only `music.youtube.com` checked)
- No input validation on video ID (assumes backend provides valid IDs)

**Temp File Access:**
- Files in temp dir accessible to other processes (low risk: auto-cleanup after 24h)
- No encryption of downloaded files

**Path Traversal:**
- Video ID used in file path (no sanitization)
- Low risk: video IDs are alphanumeric only

### 9.2 Performance Bottlenecks

**Sequential Downloads:**
- One download at a time (blocks rapid song changes)
- User must wait for download to complete before playback

**Large Files:**
- High-quality audio can be 50-100MB (long download times)
- No progress indication to user during download

**Disk I/O:**
- Temp directory writes can be slow on some systems
- No async I/O (uses blocking file operations)

**Process Startup:**
- yt-dlp process startup overhead (~100-200ms)
- Could cache process handles (but increases complexity)

### 9.3 Reliability Concerns

**yt-dlp Updates:**
- YouTube changes may break yt-dlp (requires binary updates)
- No automatic update mechanism

**Network Failures:**
- No offline support (requires network for all downloads)
- Limited retry logic (only 2 retries)

**Binary Missing:**
- App fails silently if yt-dlp not found (only verified on startup)
- User gets generic error message

**File Finding:**
- `_findDownloadedFile()` searches entire temp directory (could be inefficient)
- No guarantee yt-dlp uses expected naming pattern

### 9.4 Missing Documentation

**Binary Bundling:**
- How yt-dlp gets into app bundle not documented
- Build scripts location unclear

**Error Scenarios:**
- User-facing error messages not documented
- No troubleshooting guide

**Cache Strategy:**
- 24-hour default not explained to users
- No way for users to see cache size or manage cache

### 9.5 Unclear Logic

**File Finding:**
- `_findDownloadedFile()` searches entire temp directory (O(n) where n = temp dir files)
- Could optimize with expected filename pattern

**Extension Detection:**
- Checks multiple extensions sequentially (webm, opus, m4a, mp3, ogg)
- No priority order (checks all even if first match found)

**Stream Error Handling:**
- `cancelOnError: false` prevents stream closure on errors (intentional but complex)
- Complex cleanup logic to prevent SIGPIPE

**Cancellation Logic:**
- Small delay (50ms) before process kill to ensure streams closed
- May not be sufficient on all systems
