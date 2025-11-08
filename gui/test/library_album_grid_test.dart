import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karma_player/controllers/library_controller.dart';
import 'package:karma_player/models/album.dart';
import 'package:karma_player/models/song.dart';
import 'package:karma_player/widgets/library/library_album_grid.dart';

void main() {
  Song _song(String id, String title) {
    return Song(
      id: id,
      title: title,
      artist: 'Test Artist',
      album: 'Test Album',
      filePath: '/music/$title.flac',
      format: 'FLAC',
      duration: const Duration(minutes: 3),
    );
  }

  Album _album(String id, String name) {
    return Album(
      id: id,
      name: name,
      path: '/music/$name',
      songs: [
        _song('$id-1', 'Track One'),
        _song('$id-2', 'Track Two'),
      ],
    );
  }

  testWidgets('LibraryAlbumGrid renders albums and handles tap',
      (tester) async {
    final controller = LibraryController();
    final albums = [
      _album('a', 'Artist A - First Album'),
      _album('b', 'Artist B - Second Album'),
    ];
    controller.seedAlbums(albums);

    Album? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryAlbumGrid(
            controller: controller,
            onAlbumSelected: (album) => selected = album,
          ),
        ),
      ),
    );

    expect(find.text('First Album'), findsOneWidget);
    expect(find.text('Second Album'), findsOneWidget);

    await tester.tap(find.text('First Album').first);
    await tester.pump();

    expect(selected, isNotNull);
    expect(selected!.id, equals('a'));
  });
}
