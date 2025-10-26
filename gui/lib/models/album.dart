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

  String get artist {
    // Try to extract artist from folder name
    // Format: "Artist - Album Title..."
    final parts = name.split(' - ');
    if (parts.length >= 2) {
      return parts[0].trim();
    }
    return 'Unknown Artist';
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
