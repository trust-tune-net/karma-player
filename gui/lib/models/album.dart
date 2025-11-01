import 'song.dart';

class Album {
  final String id;
  final String name;
  final String path;
  final String? artworkPath;
  final List<Song> songs;

  Album({
    required this.id,
    required this.name,
    required this.path,
    this.artworkPath,
    required this.songs,
  });

  /// Check if a string is a valid year (4-digit, 1900-2099)
  bool _isYear(String text) {
    final trimmed = text.trim();
    if (trimmed.length != 4) return false;
    final year = int.tryParse(trimmed);
    return year != null && year >= 1900 && year <= 2099;
  }

  String get artist {
    // First, try to get artist from song metadata (ID3 tags)
    // This is more accurate than folder name parsing
    if (songs.isNotEmpty) {
      // Collect all artists from songs (excluding "Unknown Artist" and years)
      final artistCounts = <String, int>{};
      for (final song in songs) {
        final artist = song.artist.trim();
        if (artist.isNotEmpty && 
            artist != 'Unknown Artist' && 
            !_isYear(artist)) {  // Filter out years
          artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
        }
      }
      
      // If we have artists from metadata, use the most common one
      if (artistCounts.isNotEmpty) {
        final sortedArtists = artistCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return sortedArtists.first.key;
      }
    }
    
    // Fall back to folder name parsing if no metadata available
    // Handle formats: "Artist - Album", "Year - Album", "Artist - Album - Year"
    final parts = name.split(' - ');
    if (parts.length >= 2) {
      final firstPart = parts[0].trim();
      // If first part is a year, try alternative parsing or return Unknown Artist
      if (_isYear(firstPart)) {
        // Format: "Year - Album", can't extract artist from this
        return 'Unknown Artist';
      } else {
        // Format: "Artist - Album" or "Artist - Album - Year"
        return firstPart;
      }
    }
    // If no separator, check if entire name is a year
    if (_isYear(name)) {
      return 'Unknown Artist';
    }
    return name; // Single word name, use as-is
  }

  String get title {
    // Try to extract album title from folder name
    final parts = name.split(' - ');
    if (parts.length >= 2) {
      return parts.sublist(1).join(' - ').trim();
    }
    return name;
  }

  int get trackCount => songs.length;

  // Get the primary format of the album based on file extensions
  String? get format {
    if (songs.isEmpty) return null;

    // Get the most common format
    final formats = <String, int>{};
    for (final song in songs) {
      final ext = song.filePath.split('.').last.toUpperCase();
      formats[ext] = (formats[ext] ?? 0) + 1;
    }

    // Return most common format
    if (formats.isEmpty) return null;
    final sorted = formats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  // Check if it's lossless
  bool get isLossless {
    final fmt = format;
    return fmt == 'FLAC' || fmt == 'ALAC' || fmt == 'APE' || fmt == 'WAV';
  }
}
