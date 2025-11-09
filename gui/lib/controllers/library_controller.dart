import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../main.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../services/analytics_service.dart';
import '../services/metadata_service.dart';
import '../services/transmission_client.dart';
import '../utils/library_utils.dart';

enum SortCriteria { title, artist, trackCount, year }

enum LibraryViewMode { albums, files }

class LibraryController extends ChangeNotifier {
  LibraryController({
    TransmissionClient? transmissionClient,
    MetadataService? metadataService,
    AnalyticsService? analyticsService,
    this.downloadPollInterval = const Duration(seconds: 2),
    this.autoRefreshInterval = const Duration(minutes: 10),
  })  : _transmissionClient = transmissionClient ??
            TransmissionClient(baseUrl: appSettings.transmissionRpcUrl),
        _metadataService = metadataService ?? MetadataService(),
        _analyticsService = analyticsService ?? AnalyticsService();

  final TransmissionClient _transmissionClient;
  final MetadataService _metadataService;
  final AnalyticsService _analyticsService;
  final Duration downloadPollInterval;
  final Duration autoRefreshInterval;

  final Set<String> _albumsWithMetadata = {};
  final Set<String> _songsWithMetadata = {};
  List<Album> _albums = [];
  List<Song> _allSongs = [];
  Map<String, double> _downloadProgress = {};

  Album? _selectedAlbum;
  LibraryViewMode _viewMode = LibraryViewMode.albums;
  bool _isScanning = false;
  bool _isLoadingMetadata = false;
  bool _isInitialized = false;
  bool _sortAscending = true;
  bool _connectionLostNotification = false;
  bool _disposed = false;
  bool _lastKnownHealth = appSettings.apiHealthy;
  bool _groupUnknownAlbums = true;
  bool _hasUnknownAlbums = false;

  SortCriteria _sortCriteria = SortCriteria.title;
  String _statusMessage = 'No music loaded';
  String _searchQuery = '';
  String _albumTrackFilter = '';
  String? _expandedSongId;
  Set<String> _selectedFormats = {};

  Timer? _downloadPollTimer;
  Timer? _autoRefreshTimer;

  List<Album> get albums => _albums;
  List<Song> get allSongs => _allSongs;
  List<Song> get displaySongs =>
      _applySongSorting(_applySongFilters(_allSongs));
  Album? get selectedAlbum => _selectedAlbum;
  bool get isScanning => _isScanning;
  bool get isLoadingMetadata => _isLoadingMetadata;
  bool get sortAscending => _sortAscending;
  bool get hasConnectionLostNotification => _connectionLostNotification;
  bool get hasActiveFormatFilter => _selectedFormats.isNotEmpty;
  bool get hasUnknownAlbums => _hasUnknownAlbums;
  bool get groupUnknownAlbums => _groupUnknownAlbums && _hasUnknownAlbums;

  set groupUnknownAlbums(bool value) {
    if (_groupUnknownAlbums != value) {
      _groupUnknownAlbums = value;
      if (!_groupUnknownAlbums && _selectedAlbum?.id == '__unknown_group__') {
        _selectedAlbum = null;
        _albumTrackFilter = '';
      }
      _notify();
    }
  }

  bool get hasFiles => _allSongs.isNotEmpty;

  Map<String, double> get downloadProgress =>
      Map.unmodifiable(_downloadProgress);
  Set<String> get selectedFormats => Set.unmodifiable(_selectedFormats);

  SortCriteria get sortCriteria => _sortCriteria;
  LibraryViewMode get viewMode => _viewMode;
  String get statusMessage => _statusMessage;
  String get searchQuery => _searchQuery;
  String get albumTrackFilter => _albumTrackFilter;
  String? get expandedSongId => _expandedSongId;

  List<Album> get displayAlbums {
    final grouped = _groupUnknownAlbums && _hasUnknownAlbums
        ? _withGroupedUnknownAlbums(_albums)
        : List<Album>.from(_albums);
    return _applySorting(_applySearchAndFormatFilters(grouped));
  }

  Set<String> get availableFormats {
    final formats = <String>{};

    for (final album in _albums) {
      final format = album.format;
      if (format != null) {
        formats.add(format);
      }
    }

    for (final song in _allSongs) {
      final format = _getSongFormat(song);
      if (format != null) {
        formats.add(format);
      }
    }

    return formats;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _scanMusicFolder();
    _downloadPollTimer =
        Timer.periodic(downloadPollInterval, (_) => _loadDownloadsSafely());
    _autoRefreshTimer = Timer.periodic(autoRefreshInterval, (_) async {
      await _scanMusicFolder();
    });
    await _checkHealth();
  }

  @override
  void dispose() {
    _disposed = true;
    _downloadPollTimer?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void markConnectionNotificationHandled() {
    if (_connectionLostNotification) {
      _connectionLostNotification = false;
      _notify();
    }
  }

  void updateViewMode(LibraryViewMode viewMode) {
    if (_viewMode != viewMode) {
      _viewMode = viewMode;
      _notify();
    }
  }

  void selectAlbum(Album album) {
    _selectedAlbum = album;
    _notify();
  }

  void clearSelectedAlbum() {
    if (_selectedAlbum != null) {
      _selectedAlbum = null;
      _albumTrackFilter = '';
      _notify();
    }
  }

  void refreshLibrary() {
    _scanMusicFolder();
  }

  Future<void> checkHealth() => _checkHealth();

  @visibleForTesting
  void seedAlbums(List<Album> albums) {
    _albums = albums;
    _hasUnknownAlbums = albums.any((album) => _isUnknownAlbum(album));
    if (!_hasUnknownAlbums) {
      _groupUnknownAlbums = true;
    }
    _rebuildAllSongs();
    _songsWithMetadata.clear();
    _notify();
  }

  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    _notify();
  }

  void updateSortCriteria(SortCriteria criteria) {
    if (_sortCriteria != criteria) {
      _sortCriteria = criteria;
      _notify();
    }
  }

  void updateSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _notify();
    }
  }

  void updateAlbumTrackFilter(String filter) {
    if (_albumTrackFilter != filter) {
      _albumTrackFilter = filter;
      _notify();
    }
  }

  void toggleFormatSelection(String format) {
    if (_selectedFormats.contains(format)) {
      _selectedFormats.remove(format);
    } else {
      _selectedFormats.add(format);
    }
    _notify();
  }

  void clearFormatFilters() {
    if (_selectedFormats.isNotEmpty) {
      _selectedFormats = {};
      _notify();
    }
  }

  void updateExpandedSongId(String? songId) {
    if (_expandedSongId != songId) {
      _expandedSongId = songId;
      _notify();
    }
  }

  bool isSongExpanded(String songId) => _expandedSongId == songId;

  int matchingSongCount(Album album) =>
      LibraryUtils.matchingSongCount(album, _searchQuery);

  bool albumMatchesSearch(Album album) =>
      LibraryUtils.albumMatchesQuery(album, _searchQuery);

  Map<String, List<Song>> groupSongsByDisc(List<Song> songs) =>
      LibraryUtils.groupSongsByDisc(songs);

  String getDiscLabel(String folderName) =>
      LibraryUtils.getDiscLabel(folderName);

  Future<Song> ensureSongMetadata(Song song) async {
    if (_songsWithMetadata.contains(song.id) || song.bitrate != null) {
      return song;
    }

    try {
      final updatedSong = await Song.fromFileWithMetadata(
        song.filePath,
        albumName: song.album,
        artistName: song.artist,
        artworkPath: song.artworkPath,
      );

      _songsWithMetadata.add(updatedSong.id);
      _replaceSongInCollections(updatedSong);
      return updatedSong;
    } catch (error, stackTrace) {
      _analyticsService.captureError(
        error,
        stackTrace,
        context: 'library_lazy_load_song_metadata_error',
      );
      return song;
    }
  }

  Future<void> lazyLoadMetadata(Album album) async {
    if (_albumsWithMetadata.contains(album.id)) return;
    final firstSong = album.songs.isNotEmpty ? album.songs.first : null;
    if (firstSong != null && firstSong.bitrate != null) {
      _albumsWithMetadata.add(album.id);
      return;
    }

    _isLoadingMetadata = true;
    _notify();

    try {
      final updatedSongs = await Future.wait(
        album.songs.map((song) async {
          try {
            return await Song.fromFileWithMetadata(
              song.filePath,
              albumName: song.album,
              artistName: song.artist,
              artworkPath: song.artworkPath,
            );
          } catch (_) {
            return song;
          }
        }),
      );

      for (final song in updatedSongs) {
        if (song.bitrate != null) {
          _songsWithMetadata.add(song.id);
        }
      }

      final index = _albums.indexWhere((a) => a.id == album.id);
      if (index != -1) {
        _albums[index] = Album(
          id: album.id,
          name: album.name,
          path: album.path,
          artworkPath: album.artworkPath,
          songs: updatedSongs,
        );

        if (_selectedAlbum?.id == album.id) {
          _selectedAlbum = _albums[index];
        }
      }

      _albumsWithMetadata.add(album.id);
      _rebuildAllSongs();
    } catch (error, stackTrace) {
      _analyticsService.captureError(
        error,
        stackTrace,
        context: 'library_lazy_load_metadata_error',
      );
    } finally {
      _isLoadingMetadata = false;
      _notify();
    }
  }

  int? extractYear(String albumName) => LibraryUtils.extractYear(albumName);

  bool isLosslessFormat(String format) {
    const losslessFormats = ['FLAC', 'ALAC', 'APE', 'WAV', 'DSD', 'AIFF'];
    return losslessFormats.contains(format.toUpperCase());
  }

  int formatCount(String format) {
    if (_viewMode == LibraryViewMode.files) {
      return _allSongs.where((song) => _getSongFormat(song) == format).length;
    }
    return _albums.where((album) => album.format == format).length;
  }

  bool shouldIncludeAlbum(Album album) {
    if (_selectedFormats.isEmpty) return true;
    return album.format != null && _selectedFormats.contains(album.format);
  }

  Future<void> _scanMusicFolder() async {
    _setScanningState(true, 'Scanning ~/Music folder...');
    _songsWithMetadata.clear();

    try {
      final homeDir =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (homeDir == null) {
        _setScanningState(false, 'Could not find home directory',
            clearAlbums: true);
        appSettings.updateAlbumCount(0);
        return;
      }

      final musicDir = Directory(path.join(homeDir, 'Music'));
      if (!await musicDir.exists()) {
        _setScanningState(false, 'Music folder not found', clearAlbums: true);
        appSettings.updateAlbumCount(0);
        return;
      }

      final Map<String, List<Song>> albumMap = {};
      final supportedExtensions = [
        '.mp3',
        '.m4a',
        '.flac',
        '.wav',
        '.aac',
        '.ogg',
        '.webm',
        '.opus'
      ];
      final artworkNames = [
        'folder.jpg',
        'folder.png',
        'cover.jpg',
        'cover.png',
        'artwork.jpg'
      ];
      final discPatterns = [
        RegExp(r'^disc\s*\d+$', caseSensitive: false),
        RegExp(r'^cd\s*\d+$', caseSensitive: false),
        RegExp(r'^disk\s*\d+$', caseSensitive: false),
      ];

      final List<Map<String, dynamic>> filesToProcess = [];
      await for (final entity in musicDir.list(recursive: true)) {
        if (entity is! File) continue;
        final ext = path.extension(entity.path).toLowerCase();
        if (!supportedExtensions.contains(ext)) continue;

        var albumPath = path.dirname(entity.path);
        var folderName = path.basename(albumPath);

        if (albumPath == musicDir.path) {
          final fileNameWithoutExt = path.basenameWithoutExtension(entity.path);
          albumPath = entity.path;
          final albumName = fileNameWithoutExt;

          String artistName = 'Unknown Artist';
          final nameParts = albumName.split(' - ');
          if (nameParts.length >= 2) {
            final firstPart = nameParts[0].trim();
            if (!LibraryUtils.isYear(firstPart)) {
              artistName = firstPart;
            }
          } else if (!LibraryUtils.isYear(albumName)) {
            artistName = albumName;
          }

          filesToProcess.add({
            'path': entity.path,
            'albumPath': albumPath,
            'albumName': albumName,
            'artistName': artistName,
          });
          continue;
        }

        final isDiscFolder =
            discPatterns.any((pattern) => pattern.hasMatch(folderName));
        if (isDiscFolder) {
          albumPath = path.dirname(albumPath);
        }

        final albumName = path.basename(albumPath);
        String artistName = 'Unknown Artist';
        final nameParts = albumName.split(' - ');
        if (nameParts.length >= 2) {
          final firstPart = nameParts[0].trim();
          if (!LibraryUtils.isYear(firstPart)) {
            artistName = firstPart;
          }
        } else if (!LibraryUtils.isYear(albumName)) {
          artistName = albumName;
        }

        filesToProcess.add({
          'path': entity.path,
          'albumPath': albumPath,
          'albumName': albumName,
          'artistName': artistName,
        });
      }

      for (final fileInfo in filesToProcess) {
        final albumPath = fileInfo['albumPath'] as String;
        albumMap.putIfAbsent(albumPath, () => []);

        try {
          final song = Song.fromFile(
            fileInfo['path'] as String,
            albumName: fileInfo['albumName'] as String,
            artistName: fileInfo['artistName'] as String,
          );
          albumMap[albumPath]!.add(song);
        } catch (error) {
          if (kDebugMode) {
            print('[Library] Error reading file: ${fileInfo['path']} - $error');
          }
        }
      }

      final albums = <Album>[];

      for (final entry in albumMap.entries) {
        final albumPath = entry.key;
        final songs = entry.value;

        songs.sort((a, b) {
          if (a.trackNumber != null && b.trackNumber != null) {
            return a.trackNumber!.compareTo(b.trackNumber!);
          }
          return a.title.compareTo(b.title);
        });

        Song? leadMetadataSong;
        if (songs.isNotEmpty) {
          try {
            final albumMetadata = await _metadataService
                .extractAlbumMetadata(songs.first.filePath);
            if (albumMetadata.albumArtist != null &&
                albumMetadata.albumArtist!.isNotEmpty &&
                !LibraryUtils.isYear(albumMetadata.albumArtist!)) {
              final firstSong = songs.first;
              songs[0] = Song(
                id: firstSong.id,
                title: firstSong.title,
                artist: albumMetadata.albumArtist!,
                album: albumMetadata.albumName ?? firstSong.album,
                filePath: firstSong.filePath,
                duration: firstSong.duration,
                artworkPath: firstSong.artworkPath,
                trackNumber: firstSong.trackNumber,
                bitrate: firstSong.bitrate,
                sampleRate: firstSong.sampleRate,
                bitDepth: firstSong.bitDepth,
                channels: firstSong.channels,
                channelLayout: firstSong.channelLayout,
                codecDetails: firstSong.codecDetails,
                rawMetadata: firstSong.rawMetadata,
                metadataToolVersion: firstSong.metadataToolVersion,
                fileSize: firstSong.fileSize,
                format: firstSong.format,
                isEstimated: firstSong.isEstimated,
              );
            }

            leadMetadataSong = await Song.fromFileWithMetadata(
              songs.first.filePath,
              albumName: songs.first.album,
              artistName: songs.first.artist,
              artworkPath: songs.first.artworkPath,
            );
            _songsWithMetadata.add(leadMetadataSong.id);
            songs[0] = leadMetadataSong;
          } catch (error) {
            if (kDebugMode) {
              print(
                  '[Library] Could not read quick metadata for ${path.basename(albumPath)}: $error');
            }
          }
        }

        String? artworkPath;
        final albumDir = Directory(albumPath);
        for (final artworkName in artworkNames) {
          final artFile = File(path.join(albumPath, artworkName));
          if (await artFile.exists()) {
            artworkPath = artFile.path;
            break;
          }
        }

        if (artworkPath == null && await albumDir.exists()) {
          await for (final entity in albumDir.list()) {
            if (entity is! Directory) continue;
            final folderName = path.basename(entity.path);
            final isDiscFolder =
                discPatterns.any((pattern) => pattern.hasMatch(folderName));
            if (!isDiscFolder) continue;

            await for (final file in entity.list()) {
              if (file is! File) continue;
              final ext = path.extension(file.path).toLowerCase();
              if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
                artworkPath = file.path;
                break;
              }
            }
            if (artworkPath != null) break;
          }
        }

        if (artworkPath == null && await albumDir.exists()) {
          await for (final entity in albumDir.list()) {
            if (entity is! File) continue;
            final ext = path.extension(entity.path).toLowerCase();
            if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
              artworkPath = entity.path;
              break;
            }
          }
        }

        final songsWithArtwork = songs
            .map(
              (song) => _applyArtworkAndTemplate(
                song,
                artworkPath,
                leadMetadataSong,
              ),
            )
            .toList();

        albums.add(
          Album(
            id: albumPath.hashCode.toString(),
            name: path.basename(albumPath),
            path: albumPath,
            artworkPath: artworkPath,
            songs: songsWithArtwork,
          ),
        );
      }

      _albums = albums;
      _hasUnknownAlbums = albums.any((album) => _isUnknownAlbum(album));
      if (!_hasUnknownAlbums) {
        _groupUnknownAlbums = true;
      }
      _rebuildAllSongs();
      _songsWithMetadata.clear();
      _downloadProgress = {};
      _statusMessage = albums.isEmpty
          ? 'No music found in ~/Music'
          : 'Found ${albums.length} albums';
      _isScanning = false;

      appSettings.updateAlbumCount(albums.length);
      _notify();
    } catch (error, stackTrace) {
      _statusMessage = 'Error scanning: $error';
      _isScanning = false;
      _albums = [];
      _downloadProgress = {};
      _notify();

      appSettings.updateAlbumCount(0);
      _analyticsService.captureError(
        error,
        stackTrace,
        context: 'library_scan_error',
      );
    } finally {
      await _checkHealth();
    }
  }

  Future<void> _loadDownloadsSafely() async {
    try {
      await _loadDownloads();
    } catch (_) {
      // ignore errors to keep polling silent
    }
  }

  Future<void> _loadDownloads() async {
    final torrents = await _transmissionClient.getTorrents();
    final newProgress = <String, double>{};

    for (final torrent in torrents) {
      final torrentName = torrent.name;
      final progress = torrent.percentDone.toDouble();

      if (progress >= 1.0) {
        if (!appSettings.completedTorrentIds.contains(torrent.id)) {
          await appSettings.addDownloadedBytes(torrent.totalSize, torrent.id);
          if (kDebugMode) {
            print(
                'Download completed: ${torrent.name} (${(torrent.totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB)');
          }
          await _scanMusicFolder();
        }
        continue;
      }

      for (final album in _albums) {
        if (torrentName.toLowerCase().contains(album.name.toLowerCase()) ||
            album.name.toLowerCase().contains(torrentName.toLowerCase())) {
          newProgress[album.name] = progress;
          break;
        }
      }
    }

    _downloadProgress = newProgress;
    _notify();
  }

  List<Album> _applySearchAndFormatFilters(List<Album> albums) {
    var filtered = List<Album>.from(albums);
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((album) {
        final title = album.title.toLowerCase();
        final artist = album.artist.toLowerCase();
        if (title.contains(query) || artist.contains(query)) return true;

        return album.songs.any((song) {
          final songTitle = song.title.toLowerCase();
          final songArtist = song.artist.toLowerCase();
          return songTitle.contains(query) || songArtist.contains(query);
        });
      }).toList();
    }

    if (_selectedFormats.isNotEmpty) {
      filtered = filtered.where((album) {
        if (album.id == '__unknown_group__') {
          return album.songs.any((song) {
            final format = _getSongFormat(song);
            return format != null && _selectedFormats.contains(format);
          });
        }
        return album.format != null && _selectedFormats.contains(album.format);
      }).toList();
    }

    return filtered;
  }

  List<Album> _applySorting(List<Album> albums) {
    final sorted = List<Album>.from(albums);
    sorted.sort((a, b) {
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
          final aYear = extractYear(a.name);
          final bYear = extractYear(b.name);
          if (aYear != null && bYear != null) {
            comparison = aYear.compareTo(bYear);
          } else if (aYear != null) {
            comparison = -1;
          } else if (bYear != null) {
            comparison = 1;
          } else {
            comparison = a.title.compareTo(b.title);
          }
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  List<Song> _applySongFilters(List<Song> songs) {
    var filtered = List<Song>.from(songs);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((song) => LibraryUtils.matchesSongQuery(song, _searchQuery))
          .toList();
    }

    if (_selectedFormats.isNotEmpty) {
      filtered = filtered.where((song) {
        final format = _getSongFormat(song);
        return format != null && _selectedFormats.contains(format);
      }).toList();
    }

    return filtered;
  }

  List<Song> _applySongSorting(List<Song> songs) {
    final sorted = List<Song>.from(songs);
    sorted.sort((a, b) {
      int comparison = 0;
      switch (_sortCriteria) {
        case SortCriteria.title:
          comparison = a.title.compareTo(b.title);
          break;
        case SortCriteria.artist:
          comparison = a.artist.compareTo(b.artist);
          break;
        case SortCriteria.trackCount:
          comparison = (a.album ?? '').compareTo(b.album ?? '');
          break;
        case SortCriteria.year:
          final aYear = LibraryUtils.extractYear(a.album ?? a.title);
          final bYear = LibraryUtils.extractYear(b.album ?? b.title);
          if (aYear != null && bYear != null) {
            comparison = aYear.compareTo(bYear);
          } else if (aYear != null) {
            comparison = -1;
          } else if (bYear != null) {
            comparison = 1;
          } else {
            comparison = a.title.compareTo(b.title);
          }
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  void _setScanningState(bool isScanning, String message,
      {bool clearAlbums = false}) {
    _isScanning = isScanning;
    _statusMessage = message;
    if (clearAlbums) {
      _albums = [];
    }
    _notify();
  }

  Future<void> _checkHealth() async {
    final wasHealthy = _lastKnownHealth;
    final isHealthy = await appSettings.checkApiHealth();
    _lastKnownHealth = isHealthy;

    if (wasHealthy && !isHealthy && appSettings.shouldShowNetworkErrorToast()) {
      _connectionLostNotification = true;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _replaceSongInCollections(Song updatedSong) {
    for (var i = 0; i < _allSongs.length; i++) {
      if (_allSongs[i].id == updatedSong.id) {
        _allSongs[i] = updatedSong;
        break;
      }
    }

    for (var i = 0; i < _albums.length; i++) {
      final album = _albums[i];
      final songIndex =
          album.songs.indexWhere((song) => song.id == updatedSong.id);
      if (songIndex != -1) {
        final updatedSongs = List<Song>.from(album.songs);
        updatedSongs[songIndex] = updatedSong;
        _albums[i] = Album(
          id: album.id,
          name: album.name,
          path: album.path,
          artworkPath: album.artworkPath,
          songs: updatedSongs,
        );

        if (_selectedAlbum?.id == album.id) {
          _selectedAlbum = _albums[i];
        }
        break;
      }
    }

    _rebuildAllSongs();
    _notify();
  }

  void _rebuildAllSongs() {
    _allSongs = _albums.expand((album) => album.songs).toList();
  }

  Song _applyArtworkAndTemplate(
    Song song,
    String? artworkPath,
    Song? template,
  ) {
    final mergedFormat =
        song.format ?? template?.format ?? _getSongFormat(song);

    return Song(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      filePath: song.filePath,
      duration: song.duration ?? template?.duration,
      artworkPath: artworkPath ?? song.artworkPath,
      trackNumber: song.trackNumber,
      bitrate: song.bitrate ?? template?.bitrate,
      sampleRate: song.sampleRate ?? template?.sampleRate,
      bitDepth: song.bitDepth ?? template?.bitDepth,
      channels: song.channels ?? template?.channels,
      channelLayout: song.channelLayout ?? template?.channelLayout,
      codecDetails: song.codecDetails ?? template?.codecDetails,
      rawMetadata: song.rawMetadata ?? template?.rawMetadata,
      metadataToolVersion:
          song.metadataToolVersion ?? template?.metadataToolVersion,
      fileSize: song.fileSize ?? template?.fileSize,
      format: mergedFormat,
      isEstimated: song.isEstimated || (template?.isEstimated ?? false),
      httpHeaders: song.httpHeaders,
    );
  }

  String? _getSongFormat(Song song) {
    final explicitFormat = song.format;
    if (explicitFormat != null && explicitFormat.isNotEmpty) {
      return explicitFormat.toUpperCase();
    }

    final ext = path.extension(song.filePath);
    if (ext.isEmpty) return null;
    return ext.replaceFirst('.', '').toUpperCase();
  }

  bool _isUnknownAlbum(Album album) {
    final lowerAlbumName = album.name.trim().toLowerCase();
    final albumArtist = album.artist.trim().toLowerCase();

    final allUnknownArtists = album.songs.every((song) {
      final artist = song.artist.trim().toLowerCase();
      return artist.isEmpty ||
          artist == 'unknown artist' ||
          artist == lowerAlbumName;
    });

    if (!allUnknownArtists) return false;

    final allUnknownAlbums = album.songs.every((song) {
      final songAlbum = song.album?.trim().toLowerCase() ?? '';
      if (songAlbum.isEmpty || songAlbum == 'unknown album') {
        return true;
      }
      return songAlbum == lowerAlbumName;
    });

    if (!allUnknownAlbums) return false;

    return albumArtist == 'unknown artist' || albumArtist == lowerAlbumName;
  }

  List<Album> _withGroupedUnknownAlbums(List<Album> source) {
    final known = <Album>[];
    final unknown = <Album>[];

    for (final album in source) {
      if (_isUnknownAlbum(album)) {
        unknown.add(album);
      } else {
        known.add(album);
      }
    }

    if (unknown.isEmpty) return List<Album>.from(source);

    final aggregatedSongs = unknown.expand((album) => album.songs).toList();
    if (aggregatedSongs.isEmpty) return List<Album>.from(source);

    final aggregatedAlbum = Album(
      id: '__unknown_group__',
      name: 'Unsorted Audio Files',
      path: '__virtual_unknown__',
      artworkPath: null,
      songs: aggregatedSongs,
    );

    return [...known, aggregatedAlbum];
  }
}
