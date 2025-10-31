import 'dart:io';
import '../services/metadata_service.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String filePath;
  final Duration? duration;
  final String? artworkPath;
  final int? trackNumber;

  // Audiophile metadata
  final int? bitrate; // in kbps
  final int? sampleRate; // in Hz (44100, 48000, 96000, 192000, etc.)
  final int? bitDepth; // 16, 24, 32
  final int? channels; // 2, 6, 8
  final String? channelLayout; // "stereo", "5.1", "7.1(side)"
  final String? codecDetails; // "FLAC (Free Lossless Audio Codec)"
  final String? rawMetadata; // Raw FFprobe JSON (for power users)
  final String? metadataToolVersion; // "FFprobe 7.1"
  final int? fileSize; // in bytes
  final String? format; // FLAC, MP3, ALAC, etc.
  final bool isEstimated; // false = exact from FFprobe, true = estimated from file size

  // HTTP headers for streaming URLs (e.g., YouTube requires User-Agent)
  final Map<String, String>? httpHeaders;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.filePath,
    this.duration,
    this.artworkPath,
    this.trackNumber,
    this.bitrate,
    this.sampleRate,
    this.bitDepth,
    this.channels,
    this.channelLayout,
    this.codecDetails,
    this.rawMetadata,
    this.metadataToolVersion,
    this.fileSize,
    this.format,
    this.isEstimated = false, // Default to false (exact)
    this.httpHeaders,
  });

  factory Song.fromFile(String path, {String? albumName, String? artistName, String? artworkPath}) {
    // Extract basic info from file path
    final parts = path.split('/');
    final fileName = parts.last;
    // Remove only the file extension (e.g., ".flac"), not all periods
    final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));

    // Parse track number and title using simple string splitting
    int? trackNum;
    String trackTitle = nameWithoutExt;

    // Try " - " separator first (e.g., "01 - Title")
    if (nameWithoutExt.contains(' - ')) {
      final splitParts = nameWithoutExt.split(' - ');
      if (splitParts.length >= 2) {
        trackNum = int.tryParse(splitParts[0].trim());
        trackTitle = splitParts.sublist(1).join(' - ').trim();
      }
    }
    // Try ".-" separator (e.g., "01.-Title")
    else if (nameWithoutExt.contains('.-')) {
      final splitParts = nameWithoutExt.split('.-');
      if (splitParts.length >= 2) {
        trackNum = int.tryParse(splitParts[0].trim());
        trackTitle = splitParts.sublist(1).join('.-').trim();
      }
    }
    // Try ". " separator (e.g., "01. Title")
    else if (nameWithoutExt.contains('. ')) {
      final splitParts = nameWithoutExt.split('. ');
      if (splitParts.length >= 2) {
        trackNum = int.tryParse(splitParts[0].trim());
        trackTitle = splitParts.sublist(1).join('. ').trim();
      }
    }
    // Try " " separator as last resort (e.g., "01 Title")
    else if (nameWithoutExt.contains(' ')) {
      final splitParts = nameWithoutExt.split(' ');
      if (splitParts.isNotEmpty) {
        trackNum = int.tryParse(splitParts[0].trim());
        if (trackNum != null && splitParts.length > 1) {
          trackTitle = splitParts.sublist(1).join(' ').trim();
        }
      }
    }

    return Song(
      id: path.hashCode.toString(),
      title: trackTitle,
      artist: artistName ?? 'Unknown Artist',
      album: albumName,
      filePath: path,
      trackNumber: trackNum,
      artworkPath: artworkPath,
    );
  }

  // Extract full metadata including audio quality info
  // NOW READS REAL METADATA from ID3/FLAC tags!
  static Future<Song> fromFileWithMetadata(
    String path, {
    String? albumName,
    String? artistName,
    String? artworkPath,
    bool useRealMetadata = true, // New flag to enable/disable metadata reading
  }) async {
    // Create metadata service instance to read ID3 tags + FFprobe data
    final metadataService = MetadataService();
    
    if (useRealMetadata) {
      try {
        // REAL METADATA EXTRACTION
        final metadata = await metadataService.extractSongMetadata(path);
        
        return Song(
          id: path.hashCode.toString(),
          title: metadata.title ?? _extractTitleFromFilename(path),
          artist: metadata.artist ?? artistName ?? 'Unknown Artist',
          album: metadata.album ?? albumName,
          filePath: path,
          trackNumber: metadata.trackNumber,
          duration: metadata.duration,
          artworkPath: artworkPath,
          bitrate: metadata.bitrate,      // EXACT or estimated from FFprobe
          sampleRate: metadata.sampleRate,  // EXACT or estimated from FFprobe
          bitDepth: metadata.bitDepth,      // EXACT or estimated from FFprobe
          channels: metadata.channels,      // 2, 6, 8
          channelLayout: metadata.channelLayout,  // "stereo", "5.1", "7.1(side)"
          codecDetails: metadata.codecDetails,    // "FLAC (Free Lossless Audio Codec)"
          rawMetadata: metadata.rawMetadata,      // Raw FFprobe JSON
          metadataToolVersion: metadata.metadataToolVersion, // "FFprobe 7.1"
          fileSize: metadata.fileSize,
          format: metadata.format,
          isEstimated: metadata.isEstimated, // Track if quality is exact or estimated
        );
      } catch (e) {
        print('[METADATA] WARNING: Failed to read metadata, falling back to estimation: $e');
        // Fall through to estimation logic
      }
    }
    
    // FALLBACK: Use estimation (old behavior)
    print('[METADATA] Using estimation for: $path');

    // Get basic info first
    final basicSong = Song.fromFile(path, albumName: albumName, artistName: artistName, artworkPath: artworkPath);

    try {
      // Get file size
      final file = File(path);
      final fileSize = await file.length();

      // Extract format from extension
      final ext = path.split('.').last.toUpperCase();

      // Estimate audio quality based on file size and format
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
        bitDepth = null;
      }

      return Song(
        id: basicSong.id,
        title: basicSong.title,
        artist: basicSong.artist,
        album: basicSong.album,
        filePath: basicSong.filePath,
        duration: basicSong.duration,
        artworkPath: basicSong.artworkPath,
        trackNumber: basicSong.trackNumber,
        bitrate: bitrate,
        sampleRate: sampleRate,
        bitDepth: bitDepth,
        fileSize: fileSize,
        format: ext,
        isEstimated: true, // This is an estimation!
      );
    } catch (e) {
      final ext = path.split('.').last.toUpperCase();
      return Song(
        id: basicSong.id,
        title: basicSong.title,
        artist: basicSong.artist,
        album: basicSong.album,
        filePath: basicSong.filePath,
        duration: basicSong.duration,
        artworkPath: basicSong.artworkPath,
        trackNumber: basicSong.trackNumber,
        format: ext,
        isEstimated: true, // This is an estimation (fallback case)
      );
    }
  }

  // Helper to extract title from filename
  static String _extractTitleFromFilename(String path) {
    final parts = path.split('/');
    final fileName = parts.last;
    final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
    
    // Try to parse track number and title
    if (nameWithoutExt.contains(' - ')) {
      final splitParts = nameWithoutExt.split(' - ');
      if (splitParts.length >= 2) {
        return splitParts.sublist(1).join(' - ').trim();
      }
    }
    return nameWithoutExt;
  }

  String get displayTitle => '$title - $artist';

  // Format sample rate for display (e.g., "192 kHz")
  String? get sampleRateDisplay {
    if (sampleRate == null) return null;
    if (sampleRate! >= 1000) {
      final khz = sampleRate! / 1000;
      return khz % 1 == 0 ? '${khz.toInt()} kHz' : '${khz.toStringAsFixed(1)} kHz';
    }
    return '$sampleRate Hz';
  }

  // Format bit depth and sample rate together (e.g., "24/192")
  String? get qualityDisplay {
    if (bitDepth != null && sampleRate != null) {
      final sr = sampleRate! ~/ 1000; // Convert to kHz
      return '$bitDepth/$sr';
    }
    return null;
  }

  // Format file size for display
  String? get fileSizeDisplay {
    if (fileSize == null) return null;
    if (fileSize! >= 1024 * 1024 * 1024) {
      return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (fileSize! >= 1024 * 1024) {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (fileSize! >= 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(2)} KB';
    }
    return '$fileSize B';
  }

  // Check if this is lossless audio
  bool get isLossless {
    return format == 'FLAC' || format == 'ALAC' || format == 'APE' || format == 'WAV';
  }
}
