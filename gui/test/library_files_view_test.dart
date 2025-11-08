import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karma_player/controllers/library_controller.dart';
import 'package:karma_player/models/album.dart';
import 'package:karma_player/models/song.dart';
import 'package:karma_player/widgets/library/library_files_view.dart';

void main() {
  Album _album({
    required String id,
    required String name,
    required List<Song> songs,
  }) {
    return Album(
      id: id,
      name: name,
      path: '/music/$name',
      songs: songs,
    );
  }

  Song _song({
    required String id,
    required String title,
    required String artist,
    required String format,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: 'Test Album',
      filePath: '/music/$id.$format',
      format: format,
      duration: const Duration(minutes: 3),
    );
  }

  testWidgets('LibraryFilesView renders songs and handles tap', (tester) async {
    final controller = LibraryController();
    final album = _album(
      id: 'a',
      name: 'Artist - Album',
      songs: [
        _song(id: 'a1', title: 'Intro', artist: 'Artist', format: 'flac'),
        _song(id: 'a2', title: 'Outro', artist: 'Artist', format: 'mp3'),
      ],
    );

    controller.seedAlbums([album]);
    controller.updateViewMode(LibraryViewMode.files);

    Song? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryFilesView(
            controller: controller,
            songs: controller.displaySongs,
            currentSong: null,
            onSongTap: (song) => tapped = song,
            onVerifySong: (_) {},
            onOpenFolder: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Unknown format'), findsNothing);

    await tester.tap(find.text('Intro'));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.id, equals('a1'));
  });

  testWidgets('LibraryFilesView shows empty state when no files',
      (tester) async {
    final controller = LibraryController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryFilesView(
            controller: controller,
            songs: const [],
            currentSong: null,
            onSongTap: (_) {},
            onVerifySong: (_) {},
            onOpenFolder: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('No audio files found'), findsOneWidget);
  });
}
