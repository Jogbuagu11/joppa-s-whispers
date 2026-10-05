// Milestone 9: a new game opens with a story scene driven by content.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/scenes.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/main.dart' as app;

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the opening scene plays line by line, then the board appears', (
    tester,
  ) async {
    await SaveRepository().clear();
    app.main();

    final sceneScreen = find.byKey(const Key('scene_screen'));
    for (int i = 0; i < 200 && sceneScreen.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(sceneScreen, findsOneWidget);

    // What content says should be on screen.
    final start = await _content('starting_board') as Map<String, dynamic>;
    final scenes = (await _content('scenes') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final names = {
      for (final c in await _content('characters') as List<dynamic>)
        (c as Map<String, dynamic>)['id'] as String: c['name'] as String,
    };
    final scene = scenes.firstWhere((s) => s['id'] == start['opening_scene']);
    final lines = (scene['lines'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(lines.length, greaterThan(1));

    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';
    String? portrait() {
      final found = find.byKey(const Key('scene_portrait'));
      if (found.evaluate().isEmpty) return null;
      final image = tester.widget<Image>(found.first).image;
      return image is AssetImage ? image.assetName : null;
    }

    // Which portrait files exist, so the test knows what should be shown.
    final assets = (await AssetManifest.loadFromAssetBundle(
      rootBundle,
    )).listAssets().toSet();

    final portraitsBySpeaker = <String, Set<String>>{};
    for (int i = 0; i < lines.length; i++) {
      final speaker = lines[i]['speaker'] as String;
      final expression = lines[i]['expression'] as String;
      // Each line shows the right speaker name and words.
      expect(text('scene_speaker'), names[speaker]);
      expect(text('scene_text'), lines[i]['text']);
      // And exactly the portrait for that speaker and expression: the
      // expression's own picture when it exists, otherwise their neutral one.
      final expected = portraitAssetFor(speaker, expression, assets);
      expect(portrait(), expected, reason: 'line ${i + 1}');
      if (assets.contains(
        'assets/characters/char_${speaker}_$expression.jpg',
      )) {
        expect(expected, contains('char_${speaker}_$expression'));
      }
      if (expected != null) {
        portraitsBySpeaker.putIfAbsent(speaker, () => {}).add(expected);
      }
      // Tap anywhere to move on, then wait for the old portrait to finish
      // fading out (a slow device can take longer than the fade itself).
      await tester.tapAt(tester.getCenter(sceneScreen));
      await tester.pump(const Duration(milliseconds: 400));
      for (
        int wait = 0;
        wait < 30 &&
            find.byKey(const Key('scene_portrait')).evaluate().length > 1;
        wait++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    // At least one character changed expression during the scene.
    expect(
      portraitsBySpeaker.values.any((shown) => shown.length > 1),
      isTrue,
      reason: 'the opening scene should show an expression change',
    );

    // After the last line the scene closes and the board is there.
    await tester.pump(const Duration(seconds: 1));
    expect(sceneScreen, findsNothing);
    expect(find.byType(GameWidget<BoardGame>), findsOneWidget);
  });
}
