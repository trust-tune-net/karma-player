import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import '../models/song.dart';
import '../models/album.dart';
import '../services/transmission_client.dart';
import '../services/analytics_service.dart';
import '../main.dart'; // Already imports favoritesService

class LibraryScreen extends StatefulWidget {
  final Function(Song song, {List<Song>? queue, bool? isShuffled}) onSongTap;
  final Song? currentSong;

  const LibraryScreen({super.key, required this.onSongTap, this.currentSong});

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

enum SortCriteria { title, artist, trackCount, year }

class LibraryScreenState extends State<LibraryScreen> {
  List<Album> _albums = [];
  bool _isScanning = false;
  String _statusMessage = 'No music loaded';
  Album? _selectedAlbum;
  Map<String, double> _downloadProgress = {}; // Maps album names to progress
  Timer? _downloadPollTimer;
  Timer? _autoRefreshTimer; // Auto-refresh library every 10 minutes
  late final TransmissionClient _transmissionClient;
  
  // Lazy loading state
  bool _isLoadingMetadata = false;
  Set<String> _albumsWithMetadata = {}; // Track which albums have full metadata loaded
  
  // Sorting and search state
  SortCriteria _sortCriteria = SortCriteria.title;
  bool _sortAscending = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _transmissionClient = TransmissionClient(baseUrl: appSettings.transmissionRpcUrl);
    _scanMusicFolder();
    // Poll downloads every 2 seconds
    _downloadPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadDownloads());
    // Auto-refresh library and connection badge every 10 minutes
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      print('🔄 Auto-refresh: Scanning library and checking connection...');
      _scanMusicFolder(); // This also calls _checkHealth() at the end
    });
    // Check internet health only once on startup
    _checkHealth();
    
    // Listen to search input changes
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _downloadPollTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    // appSettings.checkApiHealth() calls notifyListeners()
    // which automatically updates all StatsBadges via ListenableBuilder
    await appSettings.checkApiHealth();
  }

  Future<void> _loadDownloads() async {
    try {
      // Get all active torrents from transmission
      final torrents = await _transmissionClient.getTorrents();

      // Map torrent names to album names and update progress
      final newProgress = <String, double>{};

      for (final torrent in torrents) {
        final torrentName = torrent.name;
        final progress = torrent.percentDone.toDouble();

        // Track completed torrents for statistics
        if (progress >= 1.0) {
          // Use global settings to track completions (prevents duplicate logging)
          if (!appSettings.completedTorrentIds.contains(torrent.id)) {
            // This is a newly completed torrent - add its size to stats
            await appSettings.addDownloadedBytes(torrent.totalSize, torrent.id);
            print('Download completed: ${torrent.name} (${(torrent.totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB)');

            // Trigger library refresh to show newly downloaded music
            print('🔄 Download complete: Refreshing library...');
            _scanMusicFolder(); // This also updates connection badge
          }
          // Skip showing progress for completed torrents
          continue;
        }

        // Try to match torrent name with album names
        for (final album in _albums) {
          // Check if album name is in torrent name (fuzzy match)
          if (torrentName.toLowerCase().contains(album.name.toLowerCase()) ||
              album.name.toLowerCase().contains(torrentName.toLowerCase())) {
            newProgress[album.name] = progress;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _downloadProgress = newProgress;
        });
      }
    } catch (e) {
      // Silently fail - transmission might not be ready
    }
  }

  void resetToAlbumsView() {
    if (_selectedAlbum != null) {
      setState(() {
        _selectedAlbum = null;
      });
    }
  }

  Future<void> _scanMusicFolder() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning ~/Music folder...';
      _albums = [];
    });

    try {
      // Get home directory (cross-platform: HOME on Unix, USERPROFILE on Windows)
      final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (homeDir == null) {
        setState(() {
          _statusMessage = 'Could not find home directory';
          _isScanning = false;
        });
        appSettings.updateAlbumCount(0);
        return;
      }

      // Use path.join for cross-platform path construction
      final musicDir = Directory(path.join(homeDir, 'Music'));
      if (!await musicDir.exists()) {
        setState(() {
          _statusMessage = 'Music folder not found';
          _isScanning = false;
        });
        appSettings.updateAlbumCount(0);
        return;
      }

      // Group songs by album folder
      final Map<String, List<Song>> albumMap = {};
      final supportedExtensions = ['.mp3', '.m4a', '.flac', '.wav', '.aac', '.ogg'];
      final artworkNames = ['folder.jpg', 'folder.png', 'cover.jpg', 'cover.png', 'artwork.jpg'];

      // Regex patterns for disc folders (case-insensitive)
      final discPatterns = [
        RegExp(r'^disc\s*\d+$', caseSensitive: false),
        RegExp(r'^cd\s*\d+$', caseSensitive: false),
        RegExp(r'^disk\s*\d+$', caseSensitive: false),
      ];

      // First, collect all file paths
      final List<Map<String, dynamic>> filesToProcess = [];
      await for (final entity in musicDir.list(recursive: true)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            var albumPath = path.dirname(entity.path);
            var folderName = path.basename(albumPath);

            // Check if this is a disc folder (Disc 1, CD 2, etc.)
            bool isDiscFolder = discPatterns.any((pattern) => pattern.hasMatch(folderName));

            // If it's a disc folder, use the parent folder as the album
            if (isDiscFolder) {
              albumPath = path.dirname(albumPath);
            }

            final albumName = path.basename(albumPath);

            // Extract artist from album folder name (format: "Artist - Album")
            String artistName = 'Unknown Artist';
            final nameParts = albumName.split(' - ');
            if (nameParts.length >= 2) {
              artistName = nameParts[0].trim();
            } else {
              // If no " - " separator, use the folder name as artist
              artistName = albumName;
            }

            filesToProcess.add({
              'path': entity.path,
              'albumPath': albumPath,
              'albumName': albumName,
              'artistName': artistName,
            });
          }
        }
      }

      // Now process files with lightweight metadata extraction
      for (final fileInfo in filesToProcess) {
        final albumPath = fileInfo['albumPath'] as String;
        if (!albumMap.containsKey(albumPath)) {
          albumMap[albumPath] = [];
        }

        // Extract lightweight metadata (NO ID3/FFprobe reading for fast scanning)
        // Full metadata will be loaded lazily when album is clicked
        try {
          final song = Song.fromFile(
            fileInfo['path'] as String,
            albumName: fileInfo['albumName'] as String,
            artistName: fileInfo['artistName'] as String,
          );

          albumMap[albumPath]!.add(song);
        } catch (e) {
          // Skip corrupted files silently - don't report to Glitchtip (too noisy for user libraries)
          print('[Library] Error reading file: ${fileInfo['path']} - $e');
          // Continue with next file
        }
      }

      // Create Album objects with artwork
      final albums = <Album>[];
      for (final entry in albumMap.entries) {
        final albumPath = entry.key;
        final songs = entry.value;

        // Sort songs by track number
        songs.sort((a, b) {
          if (a.trackNumber != null && b.trackNumber != null) {
            return a.trackNumber!.compareTo(b.trackNumber!);
          }
          return a.title.compareTo(b.title);
        });

        // Look for artwork in album folder
        String? artworkPath;
        final albumDir = Directory(albumPath);

        // First try common artwork names in parent folder
        for (final artworkName in artworkNames) {
          final artFile = File(path.join(albumPath, artworkName));
          if (await artFile.exists()) {
            artworkPath = artFile.path;
            break;
          }
        }

        // If not found, check if this is a multi-disc album and look inside disc folders
        if (artworkPath == null && await albumDir.exists()) {
          // Check for disc folders
          await for (final entity in albumDir.list()) {
            if (entity is Directory) {
              final folderName = path.basename(entity.path);
              bool isDiscFolder = discPatterns.any((pattern) => pattern.hasMatch(folderName));

              if (isDiscFolder) {
                // Look for artwork inside the disc folder
                await for (final file in entity.list()) {
                  if (file is File) {
                    final ext = path.extension(file.path).toLowerCase();
                    if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
                      artworkPath = file.path;
                      break;
                    }
                  }
                }
                if (artworkPath != null) break;
              }
            }
          }
        }

        // If still not found, search for ANY image file in parent folder
        if (artworkPath == null && await albumDir.exists()) {
          await for (final entity in albumDir.list()) {
            if (entity is File) {
              final ext = path.extension(entity.path).toLowerCase();
              if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
                artworkPath = entity.path;
                break;
              }
            }
          }
        }

        // Update all songs in this album to have the artwork path
        final songsWithArtwork = songs.map((song) {
          return Song(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            filePath: song.filePath,
            duration: song.duration,
            artworkPath: artworkPath,
            trackNumber: song.trackNumber,
            bitrate: song.bitrate,
            sampleRate: song.sampleRate,
            bitDepth: song.bitDepth,
            channels: song.channels,
            channelLayout: song.channelLayout,
            codecDetails: song.codecDetails,
            rawMetadata: song.rawMetadata,
            metadataToolVersion: song.metadataToolVersion,
            fileSize: song.fileSize,
            format: song.format,
            isEstimated: song.isEstimated, // CRITICAL: Preserve estimation flag
          );
        }).toList();

        albums.add(Album(
          id: albumPath.hashCode.toString(),
          name: path.basename(albumPath),
          path: albumPath,
          artworkPath: artworkPath,
          songs: songsWithArtwork,
        ));
      }

      setState(() {
        _albums = albums;
        _isScanning = false;
        _statusMessage = albums.isEmpty
            ? 'No music found in ~/Music'
            : 'Found ${albums.length} albums';
      });

      // Update global album count so it's visible on all screens
      appSettings.updateAlbumCount(albums.length);
    } catch (e, stackTrace) {
      setState(() {
        _statusMessage = 'Error scanning: $e';
        _isScanning = false;
      });
      appSettings.updateAlbumCount(0);
      
      // Report scan-level failures (file system errors, permission issues, etc.)
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'library_scan_error',
      );
    }

    // Refresh top bar stats (connection quality, plays, GB downloaded)
    await _checkHealth();
  }

  /// Lazy-load full metadata (ID3 + FFprobe) for all songs in an album
  /// Only called when album is opened and metadata is missing
  Future<void> _lazyLoadMetadata(Album album) async {
    // Check if already loaded
    if (_albumsWithMetadata.contains(album.id)) {
      return;
    }

    // Check if songs already have metadata
    final firstSong = album.songs.isNotEmpty ? album.songs.first : null;
    if (firstSong != null && firstSong.bitrate != null) {
      // Already has metadata, mark as loaded
      _albumsWithMetadata.add(album.id);
      return;
    }

    setState(() {
      _isLoadingMetadata = true;
    });

    try {
      print('[Library] Lazy-loading metadata for album: ${album.title} (${album.songs.length} songs)');
      final startTime = DateTime.now();

      // Load full metadata for all songs in parallel (faster than sequential)
      final updatedSongs = await Future.wait(
        album.songs.map((song) async {
          try {
            return await Song.fromFileWithMetadata(
              song.filePath,
              albumName: song.album,
              artistName: song.artist,
              artworkPath: song.artworkPath,
            );
          } catch (e) {
            print('[Library] ERROR loading metadata for ${song.title}: $e');
            // Return original song if metadata loading fails
            return song;
          }
        }),
      );

      final duration = DateTime.now().difference(startTime);
      print('[Library] ✓ Loaded metadata for ${album.title} in ${duration.inMilliseconds}ms');

      // Update the album in the albums list
      final albumIndex = _albums.indexWhere((a) => a.id == album.id);
      if (albumIndex != -1) {
        setState(() {
          _albums[albumIndex] = Album(
            id: album.id,
            name: album.name,
            path: album.path,
            artworkPath: album.artworkPath,
            songs: updatedSongs,
          );
          // Update selected album if this is the currently displayed album
          if (_selectedAlbum?.id == album.id) {
            _selectedAlbum = _albums[albumIndex];
          }
          _albumsWithMetadata.add(album.id);
        });
      }
    } catch (e, stackTrace) {
      print('[Library] ERROR lazy-loading metadata: $e');
      
      // Report unexpected metadata loading failures
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'library_lazy_load_metadata_error',
      );
    } finally {
      setState(() {
        _isLoadingMetadata = false;
      });
    }
  }

  /// Get filtered and sorted albums
  List<Album> get _displayAlbums {
    var albums = List<Album>.from(_albums);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      albums = albums.where((album) {
        final title = album.title.toLowerCase();
        final artist = album.artist.toLowerCase();
        return title.contains(query) || artist.contains(query);
      }).toList();
    }
    
    // Apply sorting
    albums.sort((a, b) {
      int comparison = 0;
      switch (_sortCriteria) {
        case SortCriteria.title:
          comparison = a.title.compareTo(b.title);
          break;
        case SortCriteria.artist:
          comparison = a.artist.compareTo(b.artist);
          break;
        case SortCriteria.trackCount:
          comparison = a.trackCount.compareTo(b.trackCount);
          break;
        case SortCriteria.year:
          // Extract year from album name if present (format: "Album - YYYY" or "Artist - Album - YYYY")
          final aYear = _extractYear(a.name);
          final bYear = _extractYear(b.name);
          if (aYear != null && bYear != null) {
            comparison = aYear.compareTo(bYear);
          } else if (aYear != null) {
            comparison = -1; // Albums with year come first
          } else if (bYear != null) {
            comparison = 1;
          } else {
            comparison = a.title.compareTo(b.title); // Fallback to title
          }
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
    
    return albums;
  }
  
  /// Extract year from album name (looks for 4-digit year at the end)
  int? _extractYear(String albumName) {
    // Try to find a 4-digit year (1900-2099) in the name
    final yearPattern = RegExp(r'\b(19|20)\d{2}\b');
    final match = yearPattern.firstMatch(albumName);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedAlbum != null) {
      return _buildAlbumDetailScreen(_selectedAlbum!);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final badgeSpacing = screenWidth > 1200 ? 16.0 : 8.0; // More space when maximized

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Row(
          children: [
            Text(
              'Library',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            StatsBadges(
              onConnectionTap: _checkHealth,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (_isScanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_isScanning) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          // Search and sort controls
          if (_albums.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Row(
                children: [
                  // Search bar
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF333333),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search albums or artists...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF666666),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF888888),
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Color(0xFF888888),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sort dropdown
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF333333),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sort criteria dropdown
                        PopupMenuButton<SortCriteria>(
                          icon: Icon(
                            Icons.sort,
                            color: AppColors.purple,
                            size: 18,
                          ),
                          offset: const Offset(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          color: const Color(0xFF1E1E1E),
                          onSelected: (criteria) {
                            setState(() {
                              _sortCriteria = criteria;
                            });
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: SortCriteria.title,
                              child: Row(
                                children: [
                                  Icon(
                                    _sortCriteria == SortCriteria.title
                                        ? Icons.check
                                        : Icons.check_box_outline_blank,
                                    color: _sortCriteria == SortCriteria.title
                                        ? AppColors.purple
                                        : const Color(0xFF666666),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Title',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: _sortCriteria == SortCriteria.title
                                          ? AppColors.purple
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: SortCriteria.artist,
                              child: Row(
                                children: [
                                  Icon(
                                    _sortCriteria == SortCriteria.artist
                                        ? Icons.check
                                        : Icons.check_box_outline_blank,
                                    color: _sortCriteria == SortCriteria.artist
                                        ? AppColors.purple
                                        : const Color(0xFF666666),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Artist',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: _sortCriteria == SortCriteria.artist
                                          ? AppColors.purple
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: SortCriteria.year,
                              child: Row(
                                children: [
                                  Icon(
                                    _sortCriteria == SortCriteria.year
                                        ? Icons.check
                                        : Icons.check_box_outline_blank,
                                    color: _sortCriteria == SortCriteria.year
                                        ? AppColors.purple
                                        : const Color(0xFF666666),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Year',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: _sortCriteria == SortCriteria.year
                                          ? AppColors.purple
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: SortCriteria.trackCount,
                              child: Row(
                                children: [
                                  Icon(
                                    _sortCriteria == SortCriteria.trackCount
                                        ? Icons.check
                                        : Icons.check_box_outline_blank,
                                    color: _sortCriteria == SortCriteria.trackCount
                                        ? AppColors.purple
                                        : const Color(0xFF666666),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Track Count',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: _sortCriteria == SortCriteria.trackCount
                                          ? AppColors.purple
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        // Sort order toggle button
                        IconButton(
                          icon: Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            color: AppColors.purple,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _sortAscending = !_sortAscending;
                            });
                          },
                          tooltip: _sortAscending ? 'Ascending' : 'Descending',
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _albums.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_music_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning ? 'Scanning for music...' : 'No albums found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add music to ~/Music',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : _displayAlbums.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No albums match your search',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search term',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200, // Fixed maximum width (like Melo)
                      childAspectRatio: 0.75, // Width:height ratio
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _displayAlbums.length,
                    itemBuilder: (context, index) {
                      final album = _displayAlbums[index];
                      return _buildAlbumCard(album);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(Album album) {
    final isDownloading = _downloadProgress.containsKey(album.name);
    final progress = _downloadProgress[album.name] ?? 0.0;
    final showProgress = isDownloading && progress < 1.0;

    return _AlbumCardWidget(
      album: album,
      showProgress: showProgress,
      progress: progress,
      onTap: () {
        setState(() {
          _selectedAlbum = album;
        });
      },
    );
  }

  Widget _buildAlbumDetailScreen(Album album) {
    // Trigger lazy loading of metadata if not already loaded
    if (!_albumsWithMetadata.contains(album.id) && !_isLoadingMetadata) {
      // Use addPostFrameCallback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lazyLoadMetadata(album);
      });
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Show loading indicator while fetching metadata
          if (_isLoadingMetadata)
            SliverToBoxAdapter(
              child: Container(
                color: const Color(0xFF1E1E1E),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading audio quality details...',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          SliverAppBar(
            backgroundColor: const Color(0xFF000000),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _selectedAlbum = null;
                });
              },
            ),
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double expandRatio = (constraints.maxHeight - kToolbarHeight) /
                    (280 - kToolbarHeight);

                return FlexibleSpaceBar(
                  title: Text(
                    album.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: expandRatio > 0.3 ? [
                        const Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3.0,
                          color: Color.fromARGB(128, 0, 0, 0),
                        ),
                      ] : null,
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                  background: Stack(
                fit: StackFit.expand,
                children: [
                  album.artworkPath != null
                      ? Image.file(
                          File(album.artworkPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.album, size: 128),
                            );
                          },
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.album, size: 128),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.artist,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${album.trackCount} tracks',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          if (album.songs.isNotEmpty) {
                            widget.onSongTap(album.songs.first, queue: album.songs);
                          }
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          if (album.songs.isNotEmpty) {
                            // Pick random song but pass original queue - PlaybackService shuffles internally
                            final shuffled = List<Song>.from(album.songs)..shuffle();
                            widget.onSongTap(shuffled.first, queue: album.songs, isShuffled: true);
                          }
                        },
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Tracks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = album.songs[index];
                final isPlaying = widget.currentSong?.id == song.id;

                return _TrackListItem(
                  song: song,
                  isPlaying: isPlaying,
                  onTap: () => widget.onSongTap(song, queue: album.songs),
                );
              },
              childCount: album.songs.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }
}

// Separate StatefulWidget for album card with hover state
class _AlbumCardWidget extends StatefulWidget {
  final Album album;
  final bool showProgress;
  final double progress;
  final VoidCallback onTap;

  const _AlbumCardWidget({
    required this.album,
    required this.showProgress,
    required this.progress,
    required this.onTap,
  });

  @override
  State<_AlbumCardWidget> createState() => _AlbumCardWidgetState();
}

class _AlbumCardWidgetState extends State<_AlbumCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(_isHovered ? 0.4 : 0.2),
                        blurRadius: _isHovered ? 16 : 8,
                        offset: Offset(0, _isHovered ? 8 : 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Album artwork
                        widget.album.artworkPath != null
                            ? Image.file(
                                File(widget.album.artworkPath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.album, size: 64),
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(Icons.album, size: 64),
                              ),

                        // Play button overlay on hover
                        if (_isHovered && !widget.showProgress)
                          Container(
                            color: Colors.black.withOpacity(0.4),
                            child: Center(
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFA855F7),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFA855F7).withOpacity(0.4),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                        // Download progress indicator overlay
                        if (widget.showProgress)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.5),
                              child: Stack(
                                children: [
                                  // Circular progress indicator - perfectly centered
                                  Center(
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: CircularProgressIndicator(
                                        value: widget.progress,
                                        strokeWidth: 6,
                                        backgroundColor: Colors.white.withOpacity(0.3),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ),
                                  // Percentage text positioned in the center of the circle
                                  Center(
                                    child: Text(
                                      '${(widget.progress * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
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
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.album.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (widget.album.format != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.album.isLossless
                                  ? AppColors.purple.withOpacity(0.2)
                                  : AppColors.darkGray.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: widget.album.isLossless
                                    ? AppColors.purple.withOpacity(0.5)
                                    : AppColors.gray.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              widget.album.format!,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: widget.album.isLossless
                                    ? AppColors.purple
                                    : AppColors.lighterGray,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          '${widget.album.trackCount} tracks',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Hoverable track list item
class _TrackListItem extends StatefulWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;

  const _TrackListItem({
    required this.song,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_TrackListItem> createState() => _TrackListItemState();
}

class _TrackListItemState extends State<_TrackListItem> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _soundwaveController;

  @override
  void initState() {
    super.initState();
    _soundwaveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    if (widget.isPlaying) {
      _soundwaveController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_TrackListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _soundwaveController.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _soundwaveController.stop();
    }
  }

  @override
  void dispose() {
    _soundwaveController.dispose();
    super.dispose();
  }

  String _buildAudiophileInfo() {
    final parts = <String>[];

    print('[TRACK DISPLAY] Song: ${widget.song.title}');
    print('[TRACK DISPLAY]   format: ${widget.song.format}');
    print('[TRACK DISPLAY]   bitrate: ${widget.song.bitrate}');
    print('[TRACK DISPLAY]   sampleRate: ${widget.song.sampleRate}');
    print('[TRACK DISPLAY]   bitDepth: ${widget.song.bitDepth}');
    print('[TRACK DISPLAY]   fileSize: ${widget.song.fileSize}');

    // Format (FLAC, MP3, etc.)
    if (widget.song.format != null) {
      parts.add(widget.song.format!);
    }

    // Quality (24/192, 16/44.1, etc.)
    if (widget.song.qualityDisplay != null) {
      parts.add(widget.song.qualityDisplay!);
    }

    // Bitrate
    if (widget.song.bitrate != null) {
      parts.add('${widget.song.bitrate} kbps');
    }

    // File size
    if (widget.song.fileSizeDisplay != null) {
      parts.add(widget.song.fileSizeDisplay!);
    }

    final result = parts.isNotEmpty ? parts.join(' • ') : 'Unknown format';
    print('[TRACK DISPLAY]   Result: $result');
    return result;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSoundwaveBar(double heightFactor) {
    return Container(
      width: 3,
      height: 14 * heightFactor,
      decoration: BoxDecoration(
        color: AppColors.purple,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildRatingDisplay() {
    final songPath = widget.song.filePath;
    final isFavorite = favoritesService.isFavorite(songPath);
    final rating = favoritesService.getRating(songPath);

    // Only show if song has been favorited or rated
    if (!isFavorite && rating == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Heart icon (only if favorited)
        if (isFavorite) ...[
          Icon(
            Icons.favorite,
            color: Colors.red.withOpacity(0.8),
            size: 14,
          ),
          const SizedBox(width: 4),
        ],
        // Stars (only if rated)
        if (rating > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(rating, (index) {
              return Icon(
                Icons.star,
                color: const Color(0xFFFFC107),
                size: 12,
              );
            }),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: widget.isPlaying
              ? AppColors.purple.withOpacity(0.15)
              : _isHovered
                  ? AppColors.darkGray.withOpacity(0.5)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            width: 36,
            alignment: Alignment.center,
            child: widget.isPlaying
                ? Icon(
                    Icons.volume_up,
                    color: AppColors.purple,
                    size: 20,
                  )
                : _isHovered
                    ? Icon(
                        Icons.play_circle_filled,
                        color: AppColors.purple,
                        size: 24,
                      )
                    : Text(
                        widget.song.trackNumber?.toString().padLeft(2, '0') ?? '–',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.lightGray,
                        ),
                      ),
          ),
          title: Text(
            widget.song.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: widget.isPlaying ? FontWeight.w600 : FontWeight.w500,
              color: widget.isPlaying ? AppColors.purple : AppColors.white,
            ),
          ),
          subtitle: Text(
            _buildAudiophileInfo(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.gray,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Heart & Stars
              _buildRatingDisplay(),
              if (widget.song.duration != null || widget.isPlaying)
                const SizedBox(width: 12),
              if (widget.song.duration != null) ...[
                Text(
                  _formatDuration(widget.song.duration!),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.gray,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              if (widget.isPlaying)
                AnimatedBuilder(
                  animation: _soundwaveController,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildSoundwaveBar(0.4 + (_soundwaveController.value * 0.5)),
                        const SizedBox(width: 3),
                        _buildSoundwaveBar(0.9 - (_soundwaveController.value * 0.6)),
                        const SizedBox(width: 3),
                        _buildSoundwaveBar(0.5 + (_soundwaveController.value * 0.4)),
                      ],
                    );
                  },
                ),
            ],
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

