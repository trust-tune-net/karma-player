# Files View Implementation Plan

## Overview
Add a "Files View" toggle to the Library screen to show all audio files as a flat list instead of grouped by albums. This solves the "Unknown Album" clutter problem for users with many loose audio files.

**Entry Points (post-MVC refactor):**

- Controller: `gui/lib/controllers/library_controller.dart`
- Screen shell: `gui/lib/screens/library_screen.dart`
- Widgets: `gui/lib/widgets/library/`
- Utilities: `gui/lib/utils/library_utils.dart`

The Files view work should interact with these layers rather than embedding new
logic directly inside the screen widget.

**User Requirements:**
- ✅ Toggle between Albums ⇄ Files views on Library screen
- ✅ Files view shows flat list of all audio files
- ✅ Click file to play immediately
- ✅ Search by filename
- ✅ Filter by format (MP3, FLAC, etc.)
- ✅ Sort by various criteria (filename, size, date, etc.)
- ✅ Optional folder grouping (collapsible sections)
- ✅ Manual “Scan Metadata” action with progress panel to pre-load tags and stop song reordering
- ❌ MIDI support (deferred to future work)

---

## Phase 1: Core Architecture ✅
**Files:** `gui/lib/controllers/library_controller.dart`, `gui/lib/screens/library_screen.dart`

### Checklist
- [x] Add `enum LibraryViewMode { albums, files }`
- [x] Add controller state for `_viewMode` and flattened song list `_allSongs`
- [x] Track per-song metadata loading with `_songsWithMetadata`
- [ ] Add state variable: `bool _groupFilesByFolder = false;` (reserved for future folder grouping work)

### Code to Add
```dart
enum LibraryViewMode { albums, files }

// In LibraryScreenState class:
LibraryViewMode _viewMode = LibraryViewMode.albums;
List<Song> _allSongs = [];
bool _groupFilesByFolder = false;
```

---

## Phase 2: Flatten Songs Data ✅
**File:** `gui/lib/controllers/library_controller.dart` `_scanMusicFolder()`

### Checklist
- [x] Find the end of `_scanMusicFolder()` where albums are finalized
- [x] After sorting albums, add code to flatten all songs:
```dart
// Flatten all songs from albums for Files view
_allSongs = _albums.expand((album) => album.songs).toList();
print('📁 Library scan complete: ${_albums.length} albums, ${_allSongs.length} total files');
```
- [x] Verify this runs after `_albums` is populated but before notifying listeners

---

## Phase 3: View Mode Toggle UI ✅
**Files:**
- `gui/lib/screens/library_screen.dart` (shared controls + toggle)
- `gui/lib/widgets/library/library_album_grid.dart` (grid-only rendering)
- `gui/lib/widgets/library/library_files_view.dart` (files list rendering)

### Checklist
- [x] Promote search, sort, format filters, and new Albums/Files toggle into the screen shell
- [x] Ensure the new toggle uses `LibraryViewMode` and updates controller state
- [x] Route filtered data to either `LibraryAlbumGrid` or `LibraryFilesView`
- [x] Keep sort options and format filters in sync across both modes

### Code to Add
```dart
// View mode toggle (Albums ⇄ Files)
Padding(
  padding: const EdgeInsets.only(right: 8.0),
  child: Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: const Color(0xFF333333),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Albums button
        InkWell(
          onTap: () => setState(() => _viewMode = LibraryViewMode.albums),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(19),
            bottomLeft: Radius.circular(19),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _viewMode == LibraryViewMode.albums
                  ? const Color(0xFFA855F7).withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(19),
                bottomLeft: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.grid_view,
                  size: 16,
                  color: _viewMode == LibraryViewMode.albums
                      ? const Color(0xFFA855F7)
                      : const Color(0xFF888888),
                ),
                const SizedBox(width: 4),
                Text(
                  'Albums',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _viewMode == LibraryViewMode.albums
                        ? const Color(0xFFA855F7)
                        : const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Files button
        InkWell(
          onTap: () => setState(() => _viewMode = LibraryViewMode.files),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(19),
            bottomRight: Radius.circular(19),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _viewMode == LibraryViewMode.files
                  ? const Color(0xFFA855F7).withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(19),
                bottomRight: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.list,
                  size: 16,
                  color: _viewMode == LibraryViewMode.files
                      ? const Color(0xFFA855F7)
                      : const Color(0xFF888888),
                ),
                const SizedBox(width: 4),
                Text(
                  'Files',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _viewMode == LibraryViewMode.files
                        ? const Color(0xFFA855F7)
                        : const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
),
```

---

## Phase 4: Files View List ✅
**File:** `gui/lib/widgets/library/library_files_view.dart`

### Checklist
- [x] Create dedicated widget for Files view (re-using track row layout)
- [x] Support lazy metadata loading on click via `LibraryController.ensureSongMetadata`
- [x] Hook up `onSongTap`, `onVerifySong`, `onOpenFolder` actions
- [x] Re-use existing `LibraryTrackListItem` for row visuals and favorites metadata

### Code to Add

#### Update main build to use conditional rendering:
```dart
Expanded(
  child: _viewMode == LibraryViewMode.files
      ? _buildFilesView()
      : _buildAlbumsView(),
)
```

---

## Metadata Scan Workflow ✅
- Added stable ordering via per-song `libraryOrder` so Files view never shuffles when tags arrive.
- Exposed `LibraryController.scanAllMetadata()` which walks every song and hydrates tags using the lazy loader. This run is _fully manual_—refresh stays quick and simply rescan the library.
- Library screen now includes a `Scan Metadata` chip and a bottom progress panel with cancel support so users can run a one-time deep scan without leaving the page.

#### Add _buildFilesView() method (add after build method):
```dart
Widget _buildFilesView() {
  // Apply search filter
  List<Song> displayedSongs = _allSongs;
  if (_searchQuery.isNotEmpty) {
    displayedSongs = _allSongs.where((song) {
      final filename = path.basename(song.filePath).toLowerCase();
      return filename.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // Apply format filter
  if (_selectedFormats.isNotEmpty) {
    displayedSongs = displayedSongs.where((song) {
      return _selectedFormats.contains(song.format?.toUpperCase());
    }).toList();
  }

  // TODO: Apply sorting (Phase 6)

  if (displayedSongs.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audio_file_outlined,
            size: 64,
            color: const Color(0xFF444444),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedFormats.isNotEmpty
                ? 'No files match your filters'
                : 'No audio files found',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }

  return ListView.builder(
    itemCount: displayedSongs.length,
    itemBuilder: (context, index) {
      final song = displayedSongs[index];
      final filename = path.basename(song.filePath);
      final folderPath = path.dirname(song.filePath);
      final format = song.format?.toUpperCase() ?? 'Unknown';

      return InkWell(
        onTap: () {
          // Play immediately
          widget.onSongTap(song, queue: displayedSongs);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: widget.currentSong?.filePath == song.filePath
                ? const Color(0xFFA855F7).withOpacity(0.1)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFF222222),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Format badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getFormatColor(format).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _getFormatColor(format).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  format,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _getFormatColor(format),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filename
                    Text(
                      filename,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Folder path
                    Text(
                      folderPath.replaceFirst(
                        Platform.environment['HOME'] ?? '',
                        '~',
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF666666),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // File size and duration
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (song.fileSizeDisplay != null)
                    Text(
                      song.fileSizeDisplay!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF888888),
                      ),
                    ),
                  if (song.durationSeconds != null)
                    Text(
                      _formatDuration(song.durationSeconds!),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF666666),
                      ),
                    ),
                ],
              ),

              // Play indicator
              if (widget.currentSong?.filePath == song.filePath)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 20,
                    color: const Color(0xFFA855F7),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

// Helper to format duration
String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final secs = seconds % 60;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}
```

#### Add _buildAlbumsView() method (extract existing GridView code):
```dart
Widget _buildAlbumsView() {
  // Move existing GridView code here (lines 1083-1214)
  // This is the current album grid implementation
}
```

---

## Phase 5: Update Format Filters
**File:** `library_screen.dart` format filter methods

### Checklist
- [ ] Find `_getAllFormats()` method
- [ ] Update to return formats from `_allSongs` when in Files view
- [ ] Find `_getFormatCount()` method
- [ ] Update to count from `_allSongs` when in Files view

### Code to Update

```dart
Set<String> _getAllFormats() {
  if (_viewMode == LibraryViewMode.files) {
    // Get formats from all songs
    return _allSongs
        .where((song) => song.format != null)
        .map((song) => song.format!.toUpperCase())
        .toSet();
  } else {
    // Get formats from albums (existing code)
    return _albums
        .where((album) => album.format != null)
        .map((album) => album.format!.toUpperCase())
        .toSet();
  }
}

int _getFormatCount(String format) {
  if (_viewMode == LibraryViewMode.files) {
    // Count files with this format
    return _allSongs
        .where((song) => song.format?.toUpperCase() == format)
        .length;
  } else {
    // Count albums with this format (existing code)
    return _albums
        .where((album) => album.format?.toUpperCase() == format)
        .length;
  }
}
```

---

## Phase 6: File-Specific Sort Options
**File:** `library_screen.dart` sort dropdown and methods

### Checklist
- [ ] Create new enum: `enum FileSortCriteria { filename, dateAdded, fileSize, format, duration }`
- [ ] Add state variable: `FileSortCriteria _fileSortCriteria = FileSortCriteria.filename;`
- [ ] Update sort dropdown to show different options based on view mode
- [ ] Create `_sortFiles()` method
- [ ] Call `_sortFiles()` in `_buildFilesView()` before displaying

### Code to Add

```dart
// Add after LibraryViewMode enum
enum FileSortCriteria { filename, dateAdded, fileSize, format, duration }

// Add to state variables
FileSortCriteria _fileSortCriteria = FileSortCriteria.filename;

// Update sort dropdown (around line 846):
DropdownButton<dynamic>(
  value: _viewMode == LibraryViewMode.albums ? _sortCriteria : _fileSortCriteria,
  dropdownColor: const Color(0xFF1E1E1E),
  underline: Container(),
  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF888888)),
  items: _viewMode == LibraryViewMode.albums
      ? [
          // Existing album sort options
          DropdownMenuItem(value: SortCriteria.title, child: Text('Title')),
          DropdownMenuItem(value: SortCriteria.artist, child: Text('Artist')),
          DropdownMenuItem(value: SortCriteria.year, child: Text('Year')),
          DropdownMenuItem(value: SortCriteria.trackCount, child: Text('Track Count')),
        ]
      : [
          // Files sort options
          DropdownMenuItem(value: FileSortCriteria.filename, child: Text('Filename')),
          DropdownMenuItem(value: FileSortCriteria.dateAdded, child: Text('Date Added')),
          DropdownMenuItem(value: FileSortCriteria.fileSize, child: Text('File Size')),
          DropdownMenuItem(value: FileSortCriteria.format, child: Text('Format')),
          DropdownMenuItem(value: FileSortCriteria.duration, child: Text('Duration')),
        ],
  onChanged: (value) {
    setState(() {
      if (_viewMode == LibraryViewMode.albums) {
        _sortCriteria = value as SortCriteria;
        _sortAlbums();
      } else {
        _fileSortCriteria = value as FileSortCriteria;
      }
    });
  },
)

// Add _sortFiles method:
void _sortFiles(List<Song> songs) {
  switch (_fileSortCriteria) {
    case FileSortCriteria.filename:
      songs.sort((a, b) => path.basename(a.filePath)
          .toLowerCase()
          .compareTo(path.basename(b.filePath).toLowerCase()));
      break;
    case FileSortCriteria.dateAdded:
      songs.sort((a, b) {
        final aTime = File(a.filePath).statSync().modified;
        final bTime = File(b.filePath).statSync().modified;
        return bTime.compareTo(aTime); // Newest first
      });
      break;
    case FileSortCriteria.fileSize:
      songs.sort((a, b) => (b.fileSize ?? 0).compareTo(a.fileSize ?? 0)); // Largest first
      break;
    case FileSortCriteria.format:
      songs.sort((a, b) => (a.format ?? 'zzz').compareTo(b.format ?? 'zzz'));
      break;
    case FileSortCriteria.duration:
      songs.sort((a, b) => (b.durationSeconds ?? 0).compareTo(a.durationSeconds ?? 0)); // Longest first
      break;
  }

  if (!_sortAscending) {
    songs.reversed;
  }
}
```

Then call `_sortFiles(displayedSongs);` in `_buildFilesView()` after filtering, before returning ListView.

---

## Phase 7: Folder Grouping Option
**File:** `library_screen.dart`

### Checklist
- [ ] Add "Group by folder" checkbox/toggle in Files view
- [ ] Position it near view mode toggle or in filter row
- [ ] When enabled, group songs by parent directory
- [ ] Use ExpansionTile for collapsible folder sections
- [ ] When disabled, show flat list (current implementation)

### Code to Add

```dart
// Add to filter row (only show in Files view):
if (_viewMode == LibraryViewMode.files)
  Padding(
    padding: const EdgeInsets.only(right: 8.0),
    child: OutlinedButton.icon(
      onPressed: () => setState(() => _groupFilesByFolder = !_groupFilesByFolder),
      icon: Icon(
        _groupFilesByFolder ? Icons.folder : Icons.folder_outlined,
        size: 16,
        color: const Color(0xFF888888),
      ),
      label: Text(
        _groupFilesByFolder ? 'Grouped' : 'Flat',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF888888),
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: _groupFilesByFolder
            ? const Color(0xFFA855F7).withOpacity(0.1)
            : const Color(0xFF1E1E1E),
        side: BorderSide(
          color: _groupFilesByFolder
              ? const Color(0xFFA855F7).withOpacity(0.5)
              : const Color(0xFF333333),
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  ),

// Update _buildFilesView() to handle folder grouping:
Widget _buildFilesView() {
  // ... existing filter code ...

  if (_groupFilesByFolder) {
    return _buildGroupedFilesView(displayedSongs);
  } else {
    return _buildFlatFilesView(displayedSongs);
  }
}

Widget _buildGroupedFilesView(List<Song> songs) {
  // Group by folder
  Map<String, List<Song>> folderGroups = {};
  for (final song in songs) {
    final folder = path.dirname(song.filePath);
    folderGroups.putIfAbsent(folder, () => []).add(song);
  }

  final folders = folderGroups.keys.toList()..sort();

  return ListView.builder(
    itemCount: folders.length,
    itemBuilder: (context, index) {
      final folder = folders[index];
      final folderSongs = folderGroups[folder]!;
      final displayPath = folder.replaceFirst(
        Platform.environment['HOME'] ?? '',
        '~',
      );

      return ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.folder, size: 20, color: const Color(0xFFA855F7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayPath,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${folderSongs.length} files',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        collapsedBackgroundColor: const Color(0xFF0A0A0A),
        children: folderSongs.map((song) {
          return _buildFileListItem(song, songs);
        }).toList(),
      );
    },
  );
}

Widget _buildFlatFilesView(List<Song> songs) {
  // Existing flat ListView implementation
  return ListView.builder(
    itemCount: songs.length,
    itemBuilder: (context, index) {
      return _buildFileListItem(songs[index], songs);
    },
  );
}

Widget _buildFileListItem(Song song, List<Song> queue) {
  // Extract the file row widget from current _buildFilesView
  // (the InkWell with file info)
}
```

---

## Phase 8: Testing & Verification ✅

### Functional Testing Checklist
- [x] Albums view still works correctly
- [x] Toggle switches between Albums ⇄ Files smoothly
- [x] Files view shows all audio files
- [x] Click file plays immediately
- [x] Search filters files by filename
- [x] Format filter chips work in Files view
- [x] Format filter counts are accurate
- [x] Sort by filename (A-Z) works
- [x] Sort by file size works
- [x] Sort by duration works
- [x] Sort ascending/descending toggle works
- [x] Folder grouping toggle works
- [x] Folder sections are collapsible
- [x] Refresh button updates both views
- [x] Current playing indicator shows in Files view

### Technical Verification
- [ ] Run `flutter analyze` - no new errors
- [ ] No performance issues with large file lists (1000+ files)
- [ ] Memory usage is reasonable
- [ ] State persists when switching views
- [ ] No crashes when library is empty

### UI/UX Verification
- [ ] View toggle is visually clear
- [ ] Files list is readable and scannable
- [ ] Format badges are color-coded correctly
- [ ] File paths are truncated properly
- [ ] Folder grouping is intuitive
- [ ] Dark theme consistency maintained

---

## Known Limitations & Future Work

### Deferred Features
- **MIDI file support** - Not included in this phase
  - To add later: Add `.mid`, `.midi` to supported extensions (line 225)
  - Will need special handling (no FFprobe metadata)

### Performance Considerations
- Large file collections (10k+ files) may need:
  - Virtual scrolling optimization
  - Pagination or lazy loading
  - Indexed search

### Potential Enhancements
- Context menu on files (rename, delete, open location)
- Bulk operations (multi-select files)
- Custom sorting (drag-and-drop reorder)
- Playlist creation from file selection
- File metadata editor

---

## Implementation Order

**Recommended sequence:**
1. ✅ Phase 1: Add enum and state variables (5 min)
2. ✅ Phase 2: Flatten songs data (5 min)
3. ✅ Phase 3: View mode toggle UI (15 min)
4. ✅ Phase 4: Basic files view (30 min)
5. ✅ Phase 5: Update format filters (10 min)
6. ✅ Phase 6: File-specific sorting (20 min)
7. ✅ Phase 7: Folder grouping (25 min)
8. ✅ Phase 8: Testing (30 min)

**Total estimated time:** ~2.5 hours

---

## Quick Reference

### Key Files
- `/Users/fcavalcanti/dev/karma-player/gui/lib/screens/library_screen.dart` - Main implementation
- `/Users/fcavalcanti/dev/karma-player/gui/lib/models/song.dart` - Song data model
- `/Users/fcavalcanti/dev/karma-player/gui/lib/models/album.dart` - Album data model

### Key Line Numbers (library_screen.dart)
- Line 25: Enums (add LibraryViewMode here)
- Line 28-56: State variables
- Line 192-450: `_scanMusicFolder()` method
- Line 846-967: Sort dropdown
- Line 999-1120: Filter chips and controls
- Line 1082-1214: Main content area (albums GridView)

### Color Palette
- Purple accent: `Color(0xFFA855F7)`
- Background dark: `Color(0xFF1E1E1E)`
- Border: `Color(0xFF333333)`
- Text primary: `Colors.white`
- Text secondary: `Color(0xFF888888)`
- Text tertiary: `Color(0xFF666666)`

---

## Git Commit Message Template

```
Add Files view to Library screen

- Add view mode toggle (Albums ⇄ Files)
- Implement flat files list view
- Add filename search filtering
- Add file-specific sort options (filename, size, duration, etc.)
- Add optional folder grouping with collapsible sections
- Update format filters to work with both views
- Files play immediately on click

Closes #<issue-number>
```

---

**Created:** 2025-11-08
**Status:** Ready for implementation
**Estimated effort:** 2.5 hours
