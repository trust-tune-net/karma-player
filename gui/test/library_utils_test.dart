import 'package:flutter_test/flutter_test.dart';

import 'package:karma_player/models/song.dart';
import 'package:karma_player/utils/library_utils.dart';

void main() {
  Song _song({
    required String id,
    required String filePath,
    String? title,
    String? artist,
    String? format,
    int? bitrate,
    Duration? duration,
  }) {
    return Song(
      id: id,
      title: title ?? 'Title$id',
      artist: artist ?? 'Artist$id',
      album: 'Album',
      filePath: filePath,
      format: format,
      bitrate: bitrate,
      duration: duration,
    );
  }

  group('LibraryUtils', () {
    test('detects valid years in album names', () {
      expect(LibraryUtils.isYear('1999'), isTrue);
      expect(LibraryUtils.isYear('2099'), isTrue);
      expect(LibraryUtils.isYear('2100'), isFalse);
      expect(LibraryUtils.extractYear('Album - 2004'), equals(2004));
      expect(LibraryUtils.extractYear('No year here'), isNull);
    });

    test('groups songs by disc directory and sorts labels', () {
      final songs = [
        _song(id: '1', filePath: '/music/Disc 1/track1.flac'),
        _song(id: '2', filePath: '/music/Disc 2/track2.flac'),
        _song(id: '3', filePath: '/music/Disc 1/track3.flac'),
      ];

      final grouped = LibraryUtils.groupSongsByDisc(songs);
      expect(grouped.keys.toList(), equals(['Disc 1', 'Disc 2']));
      expect(grouped['Disc 1'], hasLength(2));
      expect(LibraryUtils.getDiscLabel('cd 3'), equals('Disc 3'));
    });

    test('matches song queries across fields', () {
      final song = _song(
        id: '4',
        filePath: '/music/song.flac',
        title: 'Shimmer',
        artist: 'Aurora',
      );

      expect(LibraryUtils.matchesSongQuery(song, 'shim'), isTrue);
      expect(LibraryUtils.matchesSongQuery(song, 'aurora'), isTrue);
      expect(LibraryUtils.matchesSongQuery(song, 'other'), isFalse);
    });

    test('builds audio details summary and duration string', () {
      final song = _song(
        id: '5',
        filePath: '/music/song.mp3',
        format: 'MP3',
        bitrate: 320,
        duration: const Duration(minutes: 4, seconds: 5),
      );

      expect(LibraryUtils.audioDetailsSummary(song), contains('MP3'));
      expect(LibraryUtils.audioDetailsSummary(song), contains('320 kbps'));
      expect(LibraryUtils.formatDuration(song.duration!), equals('4:05'));
    });
  });
}
