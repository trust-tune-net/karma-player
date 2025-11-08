import 'package:flutter_test/flutter_test.dart';

import 'package:karma_player/controllers/library_controller.dart';
import 'package:karma_player/models/album.dart';
import 'package:karma_player/models/song.dart';

void main() {
  Album _createAlbum({
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

  Song _createSong({
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

  group('LibraryController', () {
    late LibraryController controller;
    late Album albumA;
    late Album albumB;

    setUp(() {
      controller = LibraryController();
      albumA = _createAlbum(
        id: 'a',
        name: 'Alpha - Debut 2001',
        songs: [
          _createSong(
              id: 'a1', title: 'Intro', artist: 'Alpha', format: 'flac'),
          _createSong(
              id: 'a2', title: 'Second', artist: 'Alpha', format: 'flac'),
        ],
      );
      albumB = _createAlbum(
        id: 'b',
        name: 'Beta - Collector 1998',
        songs: [
          _createSong(id: 'b1', title: 'Single', artist: 'Beta', format: 'mp3'),
        ],
      );

      controller.seedAlbums([albumA, albumB]);
    });

    test('sorts albums and toggles order', () {
      // Default sort is by title which places album B first (Collector < Debut)
      expect(controller.displayAlbums.first.id, equals('b'));

      controller.updateSortCriteria(SortCriteria.artist);
      expect(controller.displayAlbums.first.id, equals('a'));

      controller.toggleSortOrder();
      expect(controller.displayAlbums.first.id, equals('b'));
    });

    test('filters albums by search query including songs', () {
      controller.updateSearchQuery('single');
      final results = controller.displayAlbums;
      expect(results, hasLength(1));
      expect(results.first.id, equals('b'));
    });

    test('filters albums by selected format', () {
      controller.toggleFormatSelection('FLAC');
      expect(controller.displayAlbums, hasLength(1));
      expect(controller.displayAlbums.first.id, equals('a'));

      controller.toggleFormatSelection('FLAC');
      controller.toggleFormatSelection('MP3');
      expect(controller.displayAlbums, hasLength(1));
      expect(controller.displayAlbums.first.id, equals('b'));
    });
  });
}
