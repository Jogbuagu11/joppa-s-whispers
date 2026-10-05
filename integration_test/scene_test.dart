// Milestone 9: a new game opens with a story scene driven by content.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
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

    final portraitsSeen = <String?>{};
    for (int i = 0; i < lines.length; i++) {
      // Each line shows the right speaker name and words.
      expect(text('scene_speaker'), names[lines[i]['speaker']]);
      expect(text('scene_text'), lines[i]['text']);
      final shown = portrait();
      portraitsSeen.add(shown);
      // A portrait, when shown, belongs to the speaker.
      if (shown != null) {
        expect(shown, contains('char_${lines[i]['speaker']}_'));
      }
      // Tap anywhere to move on.
      await tester.tapAt(tester.getCenter(sceneScreen));
      await tester.pump(const Duration(milliseconds: 400));
    }
    // More than one picture was used, so portraits really swap.
    expect(portraitsSeen.whereType<String>().length, greaterThan(1));

    // After the last line the scene closes and the board is there.
    await tester.pump(const Duration(seconds: 1));
    expect(sceneScreen, findsNothing);
    expect(find.byType(GameWidget<BoardGame>), findsOneWidget);
  });
}
