import 'package:flutter_test/flutter_test.dart';
import 'package:karma_player/controllers/library_controller.dart';
import 'package:karma_player/models/album.dart';
import 'package:karma_player/models/song.dart';
import 'package:karma_player/services/metadata_service.dart';

class _FakeMetadataService extends MetadataService {
  @override
  Future<SongMetadata> extractSongMetadata(String filePath) async {
    String title = 'Tagged';
    String artist = 'Tagged Artist';
    String format = 'FLAC';
    if (filePath.contains('a1')) {
      title = 'Intro';
      artist = 'Alpha';
      format = 'FLAC';
    } else if (filePath.contains('a2')) {
      title = 'Second';
      artist = 'Alpha';
      format = 'FLAC';
    } else if (filePath.contains('b1')) {
      title = 'Single';
      artist = 'Beta';
      format = 'MP3';
    }
    return SongMetadata(
      title: title,
      artist: artist,
      album: 'Test Album',
      duration: const Duration(minutes: 4),
      bitrate: 320,
      sampleRate: 48000,
      bitDepth: 24,
      format: format,
    );
  }
}

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
    final filePath = '/music/$id.$format';
    return Song(
      id: filePath.hashCode.toString(),
      title: title,
      artist: artist,
      album: 'Test Album',
      filePath: filePath,
      format: format.toUpperCase(),
      duration: const Duration(minutes: 3),
    );
  }

  group('LibraryController', () {
    late LibraryController controller;
    late Album albumA;
    late Album albumB;

    setUp(() {
      controller = LibraryController(metadataService: _FakeMetadataService());
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

    test('files view exposes filtered, sorted songs', () {
      controller.updateViewMode(LibraryViewMode.files);
      expect(controller.displaySongs, hasLength(3));
      expect(controller.displaySongs.first.format, isNotNull);

      controller.updateSearchQuery('intro');
      expect(controller.displaySongs, hasLength(1));
      expect(controller.displaySongs.first.title, equals('Intro'));

      controller.updateSortCriteria(SortCriteria.artist);
      expect(controller.displaySongs.first.artist, equals('Alpha'));
    });

    test('format count in files view counts songs', () {
      controller.updateViewMode(LibraryViewMode.files);
      expect(controller.formatCount('FLAC'), equals(2));
      expect(controller.formatCount('MP3'), equals(1));
    });

    test('available formats includes formats from individual songs', () {
      controller.updateViewMode(LibraryViewMode.files);
      expect(controller.availableFormats, containsAll({'FLAC', 'MP3'}));
    });

    test('lazyLoadMetadata hydrates songs on demand', () async {
      final targetAlbum = controller.displayAlbums.firstWhere((a) => a.id == 'a');
      expect(
        targetAlbum.songs.every((song) => song.bitrate == null),
        isTrue,
      );

      await controller.lazyLoadMetadata(targetAlbum);

      final refreshedAlbum =
          controller.displayAlbums.firstWhere((a) => a.id == 'a');
      expect(
        refreshedAlbum.songs.every((song) => song.bitrate != null),
        isTrue,
      );
    });

    test('maintains song order when metadata updates', () async {
      controller.updateViewMode(LibraryViewMode.files);
      final originalOrder =
          controller.displaySongs.map((song) => song.filePath).toList();

      final firstSong = controller.displaySongs.first;
      final updatedSong = await controller.ensureSongMetadata(firstSong);
      expect(updatedSong.bitrate, equals(320));
      final updatedOrder =
          controller.displaySongs.map((song) => song.filePath).toList();

      expect(updatedOrder, equals(originalOrder));
    });

    test('scanAllMetadata updates every song without reordering', () async {
      controller.updateViewMode(LibraryViewMode.files);
      final originalOrder =
          controller.displaySongs.map((song) => song.filePath).toList();

      await controller.scanAllMetadata();

      expect(controller.metadataScanCompleted,
          equals(controller.metadataScanTotal));
      final updatedOrder =
          controller.displaySongs.map((song) => song.filePath).toList();
      expect(updatedOrder, equals(originalOrder));
      expect(
        controller.displaySongs.map((song) => song.bitrate),
        everyElement(isNotNull),
      );
    });

    test('scanAllMetadata ignores requests during refresh', () async {
      controller.updateViewMode(LibraryViewMode.files);
      controller.setScanningForTest(true);

      await controller.scanAllMetadata();

      controller.setScanningForTest(false);
      expect(controller.isMetadataScanRunning, isFalse);
      expect(controller.metadataScanCompleted, equals(0));
      expect(controller.metadataScanTotal, equals(0));
    });
  });
}
