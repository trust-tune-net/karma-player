# Library Improvements - Development Plan

## Overview
This document outlines the implementation plan to improve YouTube download metadata handling and library filtering capabilities in KarmaPlayer.

## Problem Statement

### Issue #1: YouTube Downloads Missing Metadata
- Downloaded songs appear in library without proper artist/album tags
- Files show as "Unknown Artist" or rely on filename parsing only
- Album artwork is missing (generic disc icon shown)

**Root Cause:** yt-dlp downloads without embedding metadata tags into files

### Issue #2: No Format Filtering in Library
- Users cannot filter library by format (FLAC, WEBM, MP3, etc.)
- Format badges are displayed but not interactive
- Difficult to separate YouTube downloads from regular library

**Root Cause:** Library UI has no format filter implementation

---

## Solution Architecture

### Phase 1: Fix YouTube Metadata Embedding (HIGH PRIORITY)
**Goal:** Embed proper ID3/metadata tags in downloaded YouTube files

**Files to Modify:**
- `gui/lib/services/youtube_download_service.dart`

**Technical Approach:**
1. Add yt-dlp metadata flags: `--embed-metadata`, `--add-metadata`, `--embed-thumbnail`
2. Ensure metadata is written to downloaded files
3. Verify metadata_god package can read embedded tags

### Phase 2: Add Format Filtering UI (MEDIUM PRIORITY)
**Goal:** Enable users to filter library by file format

**Files to Modify:**
- `gui/lib/screens/library_screen.dart`

**Technical Approach:**
1. Add format filter state management
2. Create filter chips UI component
3. Update `_displayAlbums` getter to apply format filters
4. Add helper methods for format counting and coloring

---

## Implementation Checklist

### ✅ Phase 1: YouTube Metadata Embedding

#### Step 1.1: Update yt-dlp Arguments
- [ ] Open `gui/lib/services/youtube_download_service.dart`
- [ ] Locate `Process.start()` call (around line 370)
- [ ] Add `'--embed-metadata'` flag
- [ ] Add `'--add-metadata'` flag
- [ ] Add `'--embed-thumbnail'` flag
- [ ] Add `'--convert-thumbnails'` flag with 'jpg' format
- [ ] Test download to verify metadata is embedded

**Expected Outcome:**
- Downloaded WEBM files contain embedded metadata tags
- Artist, album, title fields populated from YouTube
- Thumbnail image embedded in file

#### Step 1.2: Verify Metadata Reading
- [ ] Test that library scan detects new metadata
- [ ] Verify `metadata_god` package reads embedded tags
- [ ] Confirm album artwork displays correctly
- [ ] Check that artist/album fields are populated

**Expected Outcome:**
- YouTube downloads show proper artist/album in library
- Album artwork displays (not generic disc icon)
- Songs group correctly by artist/album

---

### ✅ Phase 2: Format Filtering UI

#### Step 2.1: Add Format Filter State
- [ ] Open `gui/lib/screens/library_screen.dart`
- [ ] Add `Set<String> _selectedFormats = {}` to state (after line 142)
- [ ] Add `bool get _hasActiveFormatFilter => _selectedFormats.isNotEmpty`

**Expected Outcome:**
- State tracks which formats are selected for filtering

#### Step 2.2: Update Display Logic
- [ ] Locate `_displayAlbums` getter (around line 578)
- [ ] Add format filter logic after search filter
- [ ] Filter albums where `album.format` matches `_selectedFormats`
- [ ] Ensure empty filter set shows all albums

**Code to Add:**
```dart
// Apply format filter
if (_selectedFormats.isNotEmpty) {
  albums = albums.where((album) {
    return album.format != null && _selectedFormats.contains(album.format);
  }).toList();
}
```

**Expected Outcome:**
- Library displays only albums matching selected formats
- Filter works in combination with search

#### Step 2.3: Add Helper Methods
- [ ] Add `Set<String> _getAllFormats()` method
- [ ] Add `int _getFormatCount(String format)` method
- [ ] Add `Color _getFormatColor(String format)` method

**Expected Outcome:**
- Helper methods extract format info from album list
- Format counts calculated dynamically
- Color coding consistent with existing badges

#### Step 2.4: Create Filter Chips UI
- [ ] Locate search bar section (around line 906)
- [ ] Add horizontal scrolling row for filter chips
- [ ] Add "Clear filters" button (shown when filters active)
- [ ] Create FilterChip for each format with count
- [ ] Apply color coding to chips
- [ ] Wire up onSelected callback to update state

**UI Layout:**
```
[Search bar]
[Clear filters] [FLAC (45)] [WEBM (12)] [MP3 (28)] [OPUS (5)] ...
```

**Expected Outcome:**
- Filter chips appear below search bar
- Chips show format name and count
- Clicking chip toggles filter on/off
- Clear button resets all filters

---

## Testing Checklist

### Phase 1 Testing: Metadata Embedding
- [ ] Download new song from YouTube Music
- [ ] Verify file appears in library with artist/album
- [ ] Check album artwork is displayed
- [ ] Inspect file metadata with external tool (e.g., MediaInfo)
- [ ] Confirm metadata_god reads tags correctly
- [ ] Test on macOS, Windows, Linux

### Phase 2 Testing: Format Filtering
- [ ] Verify all format chips appear below search bar
- [ ] Click WEBM chip - only WEBM albums shown
- [ ] Click FLAC chip - only FLAC albums shown
- [ ] Select multiple formats - albums match any selected format
- [ ] Click "Clear filters" - all albums reappear
- [ ] Combine format filter with search - both filters apply
- [ ] Verify format counts update dynamically
- [ ] Test with empty library (no chips shown)

---

## Success Criteria

### Phase 1 Success:
✅ YouTube downloads appear in library with proper artist/album
✅ Album artwork displays for YouTube downloads
✅ Metadata tags embedded in downloaded files
✅ External players can read metadata from files

### Phase 2 Success:
✅ Users can filter library by format
✅ Format chips show count per format
✅ Multiple format selection works
✅ Clear filters button resets view
✅ Filters combine with search correctly

---

## Technical Notes

### yt-dlp Metadata Flags
- `--embed-metadata`: Embeds metadata from info JSON into file
- `--add-metadata`: Adds metadata to downloaded file
- `--embed-thumbnail`: Embeds thumbnail image as cover art
- `--convert-thumbnails jpg`: Converts thumbnail to JPEG (widely supported)

### Format Detection
- Format determined by file extension via `path.extension(filePath)`
- FFprobe used for quality specs (bitrate, sample rate, codec)
- Lossless formats: FLAC, ALAC, APE, WAV, DSD
- Lossy formats: MP3, WEBM, OPUS, M4A, AAC, OGG

### Library Scan Behavior
- Initial scan: Fast, filename-based metadata only
- Lazy load: Full metadata when album opened
- YouTube downloads: Single files = separate "albums"

---

## Known Limitations

1. **Thumbnail Embedding**: WEBM/OPUS may not support embedded images (use M4A if needed)
2. **Album Grouping**: YouTube downloads are singles, each appears as separate album
3. **Playlist Support**: Current implementation downloads singles only (no playlist grouping)
4. **Metadata Cache**: May need library refresh to see updated metadata

---

## Future Enhancements (Out of Scope)

- [ ] Batch metadata editor for existing WEBM files
- [ ] YouTube Downloads section toggle
- [ ] Playlist download with album grouping
- [ ] Quality filter (sample rate, bit depth)
- [ ] Source filter (YouTube vs. local vs. torrent)
- [ ] Artwork re-download for existing files

---

## References

### File Locations
- YouTube download service: `gui/lib/services/youtube_download_service.dart`
- Library screen: `gui/lib/screens/library_screen.dart`
- Metadata service: `gui/lib/services/metadata_service.dart`
- FFprobe service: `gui/lib/services/ffprobe_service.dart`

### Key Code Sections
- yt-dlp invocation: `youtube_download_service.dart:370-380`
- Display albums getter: `library_screen.dart:578-624`
- Format badge display: `library_screen.dart:1348-1375`
- Album scanning: `library_screen.dart:171-497`

---

## Version History

- **v1.0** (2025-11-03): Initial plan created
  - Phase 1: YouTube metadata embedding
  - Phase 2: Format filtering UI
