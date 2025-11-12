import 'package:path/path.dart' as path;

import '../models/album.dart';
import '../models/song.dart';

class LibraryUtils {
  LibraryUtils._();

  static bool isYear(String text) {
    final trimmed = text.trim();
    if (trimmed.length != 4) return false;
    final year = int.tryParse(trimmed);
    return year != null && year >= 1900 && year <= 2099;
  }

  static int? extractYear(String albumName) {
    final yearPattern = RegExp(r'\b(19|20)\d{2}\b');
    final match = yearPattern.firstMatch(albumName);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
  }

  static Map<String, List<Song>> groupSongsByDisc(List<Song> songs) {
    final Map<String, List<Song>> groups = {};

    for (final song in songs) {
      final parentDir = path.dirname(song.filePath);
      final folderName = path.basename(parentDir);
      groups.putIfAbsent(folderName, () => []).add(song);
    }

    return Map.fromEntries(
      groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  static String getDiscLabel(String folderName) {
    final patterns = [
      RegExp(r'cd\s*(\d+)', caseSensitive: false),
      RegExp(r'disc\s*(\d+)', caseSensitive: false),
      RegExp(r'disk\s*(\d+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(folderName);
      if (match != null) {
        final discNumber = int.tryParse(match.group(1) ?? '');
        if (discNumber != null) {
          return 'Disc $discNumber';
        }
      }
    }

    return folderName;
  }

  static bool matchesSongQuery(Song song, String query) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    final title = song.title.toLowerCase();
    final artist = song.artist.toLowerCase();
    final albumName = song.album?.toLowerCase() ?? '';

    return title.contains(lowerQuery) ||
        artist.contains(lowerQuery) ||
        albumName.contains(lowerQuery);
  }

  static bool albumMatchesQuery(Album album, String query) {
    if (query.isEmpty) return true;

    final lowerQuery = query.toLowerCase();
    final title = album.title.toLowerCase();
    final artist = album.artist.toLowerCase();

    if (title.contains(lowerQuery) || artist.contains(lowerQuery)) {
      return true;
    }

    return album.songs.any(
      (song) =>
          song.title.toLowerCase().contains(lowerQuery) ||
          song.artist.toLowerCase().contains(lowerQuery),
    );
  }

  static int matchingSongCount(Album album, String query) {
    if (query.isEmpty) return 0;
    final lowerQuery = query.toLowerCase();
    return album.songs
        .where(
          (song) =>
              song.title.toLowerCase().contains(lowerQuery) ||
              song.artist.toLowerCase().contains(lowerQuery),
        )
        .length;
  }

  static String audioDetailsSummary(Song song) {
    final parts = <String>[];

    if (song.format != null) {
      parts.add(song.format!);
    }
    if (song.qualityDisplay != null) {
      parts.add(song.qualityDisplay!);
    }
    if (song.bitrate != null) {
      parts.add('${song.bitrate} kbps');
    }
    if (song.fileSizeDisplay != null) {
      parts.add(song.fileSizeDisplay!);
    }

    return parts.isNotEmpty ? parts.join(' • ') : 'Unknown format';
  }

  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Parse track number and title from a filename (without extension)
  /// 
  /// Supports multiple filename patterns:
  /// - "01 - Title" (space-dash-space)
  /// - "01.-Title" (dot-dash)
  /// - "01. Title" (dot-space)
  /// - "01-Title" (single dash, no spaces)
  /// - "01 -Title" (space before dash)
  /// - "01- Title" (space after dash)
  /// - "01 Title" (space only, fallback)
  /// 
  /// Returns a record with `trackNumber` (int?) and `title` (String).
  /// If no track number is found, `trackNumber` is null and `title` is the full filename.
  static ({int? trackNumber, String title}) parseTrackNumberAndTitle(String nameWithoutExt) {
    int? trackNum;
    String trackTitle = nameWithoutExt;

    // Try " - " separator first (e.g., "01 - Title")
    if (nameWithoutExt.contains(' - ')) {
      final splitParts = nameWithoutExt.split(' - ');
      if (splitParts.length >= 2) {
        trackNum = int.tryParse(splitParts[0].trim());
        if (trackNum != null) {
          trackTitle = splitParts.sublist(1).join(' - ').trim();
        }
      }
    }
    // Try ".-" separator (e.g., "01.-Title")
    else if (nameWithoutExt.contains('.-')) {
      final splitParts = nameWithoutExt.split('.-');
      if (splitParts.length >= 2) {
        trackNum = int.tryParse(splitParts[0].trim());
        if (trackNum != null) {
          trackTitle = splitParts.sublist(1).join('.-').trim();
        }
      }
    }
    // Try ". " separator (e.g., "01. Title")
    else if (nameWithoutExt.contains('. ')) {
      final splitParts = nameWithoutExt.split('. ');
      if (splitParts.length >= 2) {
        trackNum = int.tryParse(splitParts[0].trim());
        if (trackNum != null) {
          trackTitle = splitParts.sublist(1).join('. ').trim();
        }
      }
    }
    // Try single-dash separator with optional spaces (e.g., "01-Title", "01 -Title", "01- Title")
    // This regex matches: digits, optional whitespace, dash, optional whitespace, rest of string
    else {
      final singleDashPattern = RegExp(r'^(\d+)\s*-\s*(.+)$');
      final match = singleDashPattern.firstMatch(nameWithoutExt);
      if (match != null) {
        trackNum = int.tryParse(match.group(1)!.trim());
        if (trackNum != null) {
          trackTitle = match.group(2)!.trim();
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
    }

    return (trackNumber: trackNum, title: trackTitle);
  }
}
