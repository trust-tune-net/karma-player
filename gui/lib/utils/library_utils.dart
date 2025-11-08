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
}
