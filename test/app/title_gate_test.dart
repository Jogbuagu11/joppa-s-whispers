import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/title_gate.dart';

import '../support/comfort_fakes.dart';

const _text = {
  'welcome_title': 'Welcome to Joppa',
  'welcome_body': 'By tapping Play you agree to our Terms and Privacy Policy.',
  'welcome_terms': 'Terms of Service',
  'welcome_privacy': 'Privacy Policy',
  'welcome_play': 'Play',
};

void main() {
  late Directory folder;
  late List<String> opened;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('welcome_test');
    opened = [];
  });
  tearDown(() => folder.deleteSync(recursive: true));

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: TitleGate(
          key: UniqueKey(),
          store: WelcomeStore(directory: () async => folder),
          onOpenPage: opened.add,
          hold: const Duration(milliseconds: 50),
          loadText: () async => _text,
          child: const Scaffold(key: Key('the_game')),
        ),
      ),
    );
  }

  /// The title holds for a moment and reads a file: let both finish.
  Future<void> letItOpen(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      // Real time for the file, the test's clock for the hold.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a first launch: the title, then the welcome, then the game', (
    tester,
  ) async {
    useLargestText(tester);
    await show(tester);
    expect(find.byKey(const Key('title_screen')), findsOneWidget);
    expect(find.text('Whispers'), findsOneWidget);
    expect(find.byKey(const Key('welcome')), findsNothing);
    expect(find.byKey(const Key('the_game')), findsNothing);

    await letItOpen(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('welcome')), findsOneWidget);
    expect(find.text('Welcome to Joppa'), findsOneWidget);
    // The game is not built behind it.
    expect(find.byKey(const Key('the_game')), findsNothing);

    // Both documents can be read before agreeing.
    await tester.tap(find.byKey(const Key('welcome_terms')));
    await tester.tap(find.byKey(const Key('welcome_privacy')));
    expect(opened, ['terms', 'privacy']);
    expect(find.byKey(const Key('the_game')), findsNothing);

    await tester.tap(find.byKey(const Key('welcome_play')));
    await letItOpen(tester);
    expect(find.byKey(const Key('the_game')), findsOneWidget);
    expect(find.byKey(const Key('title_screen')), findsNothing);
  });

  testWidgets('the next launch goes from the title straight to the game', (
    tester,
  ) async {
    await tester.runAsync(
      () => WelcomeStore(
        directory: () async => folder,
      ).agree(DateTime.utc(2026, 10, 10)),
    );
    await show(tester);
    expect(find.byKey(const Key('title_screen')), findsOneWidget);
    await letItOpen(tester);
    expect(find.byKey(const Key('welcome')), findsNothing);
    expect(find.byKey(const Key('the_game')), findsOneWidget);
  });

  testWidgets('a damaged record means the welcome is simply shown again', (
    tester,
  ) async {
    File('${folder.path}/welcome.json').writeAsStringSync('not json');
    await show(tester);
    await letItOpen(tester);
    expect(find.byKey(const Key('welcome')), findsOneWidget);
  });
}
