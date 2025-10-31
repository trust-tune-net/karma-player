import 'dart:io';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path;
import 'ffprobe_service.dart';

/// Service for extracting metadata from audio files
/// Handles ID3 tags, FLAC tags, and EXACT audio quality via FFprobe
class MetadataService {
  final FFprobeService _ffprobeService = FFprobeService();
  
  /// Initialize metadata_god (must be called before use)
  static Future<void> initialize() async {
    try {
      MetadataGod.initialize();
      _log('[MetadataService] Initialized successfully');
    } catch (e) {
      _log('[MetadataService] WARNING: Failed to initialize: $e');
    }
  }
  
  /// Verify FFprobe is available
  Future<bool> verifyFFprobe() async {
    return await _ffprobeService.verifyFFprobe();
  }

  /// Extract album-level metadata from the first file in a folder
  /// Used during library scanning for quick album info
  Future<AlbumMetadata> extractAlbumMetadata(String firstFilePath) async {
    try {
      _log('[MetadataService] Extracting album metadata from: $firstFilePath');
      
      final metadata = await MetadataGod.readMetadata(file: firstFilePath);
      
      final albumMetadata = AlbumMetadata(
        albumName: metadata.album?.trim(),
        albumArtist: metadata.albumArtist?.trim() ?? metadata.artist?.trim(),
        year: metadata.year,
        genre: metadata.genre,
        // Note: metadata_god doesn't provide raw picture data in v1.1.0
        // Album art will be loaded from folder images as before
      );
      
      _log('[MetadataService] ✓ Album: ${albumMetadata.albumName ?? "Unknown"}');
      _log('[MetadataService] ✓ Artist: ${albumMetadata.albumArtist ?? "Unknown"}');
      
      return albumMetadata;
    } catch (e) {
      _log('[MetadataService] ERROR reading album metadata: $e');
      // Fallback to folder-based extraction
      return AlbumMetadata.fromFolderPath(firstFilePath);
    }
  }

  /// Extract full song metadata including audio quality details
  /// Uses FFprobe for EXACT audio quality (audiophile-grade accuracy)
  /// Falls back to estimation if FFprobe fails
  Future<SongMetadata> extractSongMetadata(String filePath) async {
    try {
      _log('[MetadataService] Extracting song metadata from: ${path.basename(filePath)}');
      
      // 1. Read ID3 tags (title, artist, album, etc.)
      final metadata = await MetadataGod.readMetadata(file: filePath);
      final file = File(filePath);
      final fileSize = await file.length();
      final ext = path.extension(filePath).toUpperCase().substring(1); // Remove dot
      
      // 2. Try to read EXACT audio quality from FFprobe
      AudioStreamInfo? audioInfo;
      bool isEstimated = false;
      
      try {
        audioInfo = await _ffprobeService.extractAudioInfo(filePath);
        _log('[MetadataService] ✓ Using EXACT quality from FFprobe');
      } catch (e) {
        _log('[MetadataService] ⚠️  FFprobe failed, falling back to estimation: $e');
        // Fall back to estimation
        final qualityEstimate = _estimateAudioQuality(fileSize, ext);
        audioInfo = AudioStreamInfo(
          bitrate: qualityEstimate['bitrate'],
          sampleRate: qualityEstimate['sampleRate'],
          bitDepth: qualityEstimate['bitDepth'],
          isEstimated: true,
        );
        isEstimated = true;
      }
      
      // 3. Merge ID3 metadata with audio quality
      final songMetadata = SongMetadata(
        title: metadata.title?.trim(),
        artist: metadata.artist?.trim(),
        album: metadata.album?.trim(),
        trackNumber: metadata.trackNumber,
        year: metadata.year,
        genre: metadata.genre,
        duration: metadata.durationMs != null 
            ? Duration(milliseconds: metadata.durationMs!.toInt())
            : null,
        fileSize: fileSize,
        format: ext,
        // EXACT audio quality from FFprobe (or estimated if FFprobe failed)
        bitrate: audioInfo.bitrate,
        sampleRate: audioInfo.sampleRate,
        bitDepth: audioInfo.bitDepth,
        channels: audioInfo.channels,
        channelLayout: audioInfo.channelLayout,
        codecDetails: audioInfo.codecLongName,
        rawMetadata: audioInfo.rawJson,
        metadataToolVersion: audioInfo.ffprobeVersion != null 
            ? 'FFprobe ${audioInfo.ffprobeVersion}'
            : null,
        isEstimated: isEstimated,
      );
      
      _log('[MetadataService] ✓ Title: ${songMetadata.title ?? "Unknown"}');
      _log('[MetadataService] ✓ Artist: ${songMetadata.artist ?? "Unknown"}');
      _log('[MetadataService] ✓ Quality: ${audioInfo.bitDepth != null && audioInfo.sampleRate != null ? "${audioInfo.bitDepth}/${audioInfo.sampleRate! ~/ 1000}kHz" : ""} @ ${audioInfo.bitrate}kbps ${isEstimated ? "(estimated)" : "(EXACT)"}');
      
      return songMetadata;
    } catch (e) {
      _log('[MetadataService] ERROR reading song metadata: $e');
      // Fallback to estimation-based extraction
      return SongMetadata.fromEstimation(filePath);
    }
  }

  /// Estimate audio quality from file size
  static Map<String, int?> _estimateAudioQuality(int fileSize, String ext) {
    int? sampleRate;
    int? bitDepth;
    int? bitrate;
    
    if (ext == 'FLAC') {
      final mbSize = fileSize / (1024 * 1024);
      if (mbSize > 100) {
        sampleRate = 192000;
        bitDepth = 24;
        bitrate = 4608;
      } else if (mbSize > 50) {
        sampleRate = 96000;
        bitDepth = 24;
        bitrate = 2304;
      } else if (mbSize > 30) {
        sampleRate = 48000;
        bitDepth = 24;
        bitrate = 1152;
      } else {
        sampleRate = 44100;
        bitDepth = 16;
        bitrate = 1411;
      }
    } else if (ext == 'MP3') {
      final mbSize = fileSize / (1024 * 1024);
      if (mbSize > 8) {
        bitrate = 320;
      } else if (mbSize > 6) {
        bitrate = 256;
      } else if (mbSize > 4) {
        bitrate = 192;
      } else {
        bitrate = 128;
      }
      sampleRate = 44100;
    }
    
    return {
      'sampleRate': sampleRate,
      'bitDepth': bitDepth,
      'bitrate': bitrate,
    };
  }

  /// Log to both console and file
  static void _log(String message) {
    print(message);
    
    // Also write to /tmp/log/karmaplayer.log
    try {
      final logDir = Directory('/tmp/log');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      
      final logFile = File('/tmp/log/karmaplayer.log');
      final timestamp = DateTime.now().toIso8601String();
      logFile.writeAsStringSync(
        '[$timestamp] $message\n',
        mode: FileMode.append,
      );
    } catch (e) {
      // Silently fail if logging to file doesn't work
      print('[MetadataService] Failed to write to log file: $e');
    }
  }
}

/// Album-level metadata extracted from first file
class AlbumMetadata {
  final String? albumName;
  final String? albumArtist;
  final int? year;
  final String? genre;

  AlbumMetadata({
    this.albumName,
    this.albumArtist,
    this.year,
    this.genre,
  });

  /// Fallback: extract from folder path when metadata reading fails
  factory AlbumMetadata.fromFolderPath(String filePath) {
    final folderPath = path.dirname(filePath);
    final folderName = path.basename(folderPath);
    
    // Try to extract artist from folder name (format: "Artist - Album")
    String? artist;
    String? album;
    
    final parts = folderName.split(' - ');
    if (parts.length >= 2) {
      artist = parts[0].trim();
      album = parts.sublist(1).join(' - ').trim();
    } else {
      // No separator, use folder name as both
      artist = folderName;
      album = folderName;
    }
    
    return AlbumMetadata(
      albumName: album,
      albumArtist: artist,
    );
  }
}

/// Song-level metadata with audio quality details
class SongMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final int? trackNumber;
  final int? year;
  final String? genre;
  final Duration? duration;
  final int? fileSize;
  final String? format;
  
  // Audio quality
  final int? bitrate;     // in kbps
  final int? sampleRate;  // in Hz
  final int? bitDepth;    // 16, 24, 32
  final int? channels;    // 2, 6, 8
  final String? channelLayout;  // "stereo", "5.1", "7.1(side)"
  final String? codecDetails;   // "FLAC (Free Lossless Audio Codec)"
  final String? rawMetadata;      // Raw FFprobe JSON (for power users)
  final String? metadataToolVersion; // "FFprobe 7.1"
  final bool isEstimated; // false = exact from FFprobe, true = estimated from file size

  SongMetadata({
    this.title,
    this.artist,
    this.album,
    this.trackNumber,
    this.year,
    this.genre,
    this.duration,
    this.fileSize,
    this.format,
    this.bitrate,
    this.sampleRate,
    this.bitDepth,
    this.channels,
    this.channelLayout,
    this.codecDetails,
    this.rawMetadata,
    this.metadataToolVersion,
    this.isEstimated = false, // Default to false (exact)
  });

  /// Fallback: estimate quality from file size (current behavior)
  factory SongMetadata.fromEstimation(String filePath) {
    final file = File(filePath);
    final fileSize = file.lengthSync();
    final ext = path.extension(filePath).toUpperCase().substring(1);
    
    // Extract title from filename
    final fileName = path.basenameWithoutExtension(filePath);
    String title = fileName;
    int? trackNumber;
    
    // Try to parse track number from filename
    if (fileName.contains(' - ')) {
      final parts = fileName.split(' - ');
      if (parts.length >= 2) {
        trackNumber = int.tryParse(parts[0].trim());
        title = parts.sublist(1).join(' - ').trim();
      }
    }
    
    // Estimate bitrate from file size (CD quality baseline)
    int? bitrate;
    int? sampleRate;
    int? bitDepth;
    
    if (ext == 'FLAC') {
      final mbSize = fileSize / (1024 * 1024);
      if (mbSize > 100) {
        sampleRate = 192000;
        bitDepth = 24;
        bitrate = 4608;
      } else if (mbSize > 50) {
        sampleRate = 96000;
        bitDepth = 24;
        bitrate = 2304;
      } else if (mbSize > 30) {
        sampleRate = 48000;
        bitDepth = 24;
        bitrate = 1152;
      } else {
        sampleRate = 44100;
        bitDepth = 16;
        bitrate = 1411;
      }
    } else if (ext == 'MP3') {
      final mbSize = fileSize / (1024 * 1024);
      if (mbSize > 8) {
        bitrate = 320;
      } else if (mbSize > 6) {
        bitrate = 256;
      } else if (mbSize > 4) {
        bitrate = 192;
      } else {
        bitrate = 128;
      }
      sampleRate = 44100;
    }
    
    return SongMetadata(
      title: title,
      trackNumber: trackNumber,
      fileSize: fileSize,
      format: ext,
      bitrate: bitrate,
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      isEstimated: true, // This is an estimation!
    );
  }
}

