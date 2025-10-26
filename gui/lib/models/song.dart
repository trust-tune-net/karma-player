import 'dart:io';

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
  final int? fileSize; // in bytes
  final String? format; // FLAC, MP3, ALAC, etc.

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
    this.fileSize,
    this.format,
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
  static Future<Song> fromFileWithMetadata(
    String path, {
    String? albumName,
    String? artistName,
    String? artworkPath,
  }) async {
    print('[METADATA] Extracting metadata for: $path');

    // Get basic info first
    final basicSong = Song.fromFile(path, albumName: albumName, artistName: artistName, artworkPath: artworkPath);

    try {
      // Get file size
      final file = File(path);
      final fileSize = await file.length();

      // Extract format from extension
      final ext = path.split('.').last.toUpperCase();
      print('[METADATA] Format: $ext, Size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');

      // Estimate audio quality based on file size and format
      int? sampleRate;
      int? bitDepth;
      int? bitrate;

      if (ext == 'FLAC') {
        // Estimate based on file size per minute
        // Typical FLAC sizes:
        // 16/44.1 (CD quality): ~25-30 MB/min
        // 24/96 (Hi-Res): ~60-80 MB/min
        // 24/192 (Ultra Hi-Res): ~120-150 MB/min
        final mbSize = fileSize / (1024 * 1024);

        if (mbSize > 100) {
          sampleRate = 192000;
          bitDepth = 24;
          bitrate = 4608; // 24bit * 192kHz * 2 channels / 1000
        } else if (mbSize > 50) {
          sampleRate = 96000;
          bitDepth = 24;
          bitrate = 2304; // 24bit * 96kHz * 2 channels / 1000
        } else if (mbSize > 30) {
          sampleRate = 48000;
          bitDepth = 24;
          bitrate = 1152;
        } else {
          sampleRate = 44100;
          bitDepth = 16;
          bitrate = 1411; // CD quality
        }
      } else if (ext == 'MP3') {
        // MP3 bitrates are typically 128, 192, 256, 320 kbps
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
        bitDepth = null; // MP3 doesn't have fixed bit depth
      }

      print('[METADATA] Determined: ${bitDepth != null && sampleRate != null ? "$bitDepth/${sampleRate! ~/ 1000}" : "N/A"}, Bitrate: ${bitrate ?? "N/A"} kbps');

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
      );
    } catch (e) {
      // If extraction fails, return basic song with just format
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
      );
    }
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
