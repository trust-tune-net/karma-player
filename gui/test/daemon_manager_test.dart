import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karma_player/services/daemon_manager.dart';
import 'package:path/path.dart' as path;

void main() {
  test('default download directory resolves to Music folder', () {
    final homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    expect(homeDir, isNotNull, reason: 'HOME/USERPROFILE should be defined');

    final expected = path.join(homeDir!, 'Music');
    final manager = DaemonManager(homeDirProvider: () => homeDir);
    final actual = manager.getDownloadDir(null);

    if (actual != expected) {
      fail('homeDir: $homeDir actual: $actual expected: $expected');
    }
  });
}
