import 'package:flutter_test/flutter_test.dart';
import 'package:karma_player/services/transmission_client.dart';

void main() {
  test('Transmission client can connect and get session', () async {
    final client = TransmissionClient();

    // Test connection
    final connected = await client.testConnection();
    expect(connected, isTrue);

    // Get session info
    final session = await client.getSession();
    expect(session, isNotEmpty);
    expect(session['download-dir'], isNotNull);

    print('Session info: ${session['download-dir']}');
    print('Version: ${session['version']}');
  });

  test('Transmission client can get torrents', () async {
    final client = TransmissionClient();

    // Get all torrents (should be empty initially)
    final torrents = await client.getTorrents();
    expect(torrents, isA<List>());

    print('Found ${torrents.length} torrents');
  });
}
