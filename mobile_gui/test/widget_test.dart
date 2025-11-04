// Basic Flutter widget test for KarmaPlayer Mobile

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:karmaplayer_mobile/main.dart';

void main() {
  testWidgets('App loads and shows splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const ProviderScope(child: KarmaPlayerApp()));

    // Verify that the app name appears
    expect(find.text('KarmaPlayer'), findsOneWidget);

    // Verify that subtitle appears
    expect(find.text('Audiophile Music Companion'), findsOneWidget);

    // Verify that initializing text appears
    expect(find.text('Initializing...'), findsOneWidget);

    // Verify that music icon appears
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });
}
