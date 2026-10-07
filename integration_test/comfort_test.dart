// Milestone 24: sound, vibration and tier numbers each have their own
// switch, and the board still fits when the phone asks for very large text.
// The speaker and vibration are stand-ins for the game part; the last test
// plays one real sound to prove the sound files load on a real device.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';
import 'package:whispers_of_joppa/features/settings/notifications_controller.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';
import 'package:whispers_of_joppa/services/device_feedback_player.dart';

import '../test/support/comfort_fakes.dart';
import '../test/support/notification_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sound, vibration and tier numbers follow their switches', (
    tester,
  ) async {
    // The phone asks for text twice the usual size; the game allows it to
    // grow only as far as its screens have room for.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final player = FakeFeedbackPlayer();
    final comfort = fakeComfort(player);
    await SaveRepository().clear();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: maxTextScale,
          child: child ?? const SizedBox.shrink(),
        ),
        home: BoardScreen(
          playOpeningScene: false,
          playTutorial: false,
          notifications: NotificationsController(
            service: FakeNotificationService(),
            repository: tempPrefsRepository(),
          ),
          comfort: comfort,
        ),
      ),
    );
    final board = find.byType(GameWidget<BoardGame>);
    Future<void> wait([int tenths = 10]) async {
      for (int i = 0; i < tenths; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await wait();
    // Everything around the board fits at the largest text size.
    expect(tester.takeException(), isNull);
    expect(player.prepared, 1);

    // Where the first generator is drawn.
    final start =
        jsonDecode(await rootBundle.loadString('content/starting_board.json'))
            as Map<String, dynamic>;
    final generator =
        (start['generators'] as List<dynamic>).first as Map<String, dynamic>;
    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    final generatorCentre = Offset(
      rect.left +
          (rect.width - BoardGame.cols * cell) / 2 +
          ((generator['col'] as int) + 0.5) * cell,
      rect.top +
          (rect.height - BoardGame.rows * cell) / 2 +
          ((generator['row'] as int) + 0.5) * cell,
    );

    // A generator tap is heard and felt.
    await tester.tapAt(generatorCentre);
    await wait(5);
    expect(player.sounds, [GameCue.spawn]);
    expect(player.haptics, [HapticStrength.light]);

    // The settings button opens all the switches.
    final game = tester.widget<GameWidget<BoardGame>>(board).game;
    Future<void> flip(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await wait();
    }

    await tester.tap(find.byKey(const Key('notifications_button')));
    await wait();
    expect(tester.takeException(), isNull);
    expect(game?.showTierNumbers, isFalse);
    await flip('comfort_sound');
    await flip('comfort_tier_numbers');
    expect(comfort.prefs.sound, isFalse);
    expect(comfort.prefs.haptics, isTrue);
    expect(game?.showTierNumbers, isTrue);
    // Turning sound off made no sound.
    expect(player.sounds, [GameCue.spawn]);

    // Back on the board: items now carry numbers, taps are felt, not heard.
    await tester.pageBack();
    await wait();
    await tester.tapAt(generatorCentre);
    await wait(5);
    expect(tester.takeException(), isNull);
    expect(player.sounds, [GameCue.spawn]);
    expect(player.haptics, [HapticStrength.light, HapticStrength.light]);

    // Vibration has its own switch.
    await tester.tap(find.byKey(const Key('notifications_button')));
    await wait();
    await flip('comfort_haptics');
    await tester.pageBack();
    await wait();
    final felt = player.haptics.length;
    await tester.tapAt(generatorCentre);
    await wait(5);
    expect(player.haptics, hasLength(felt));
    expect(player.sounds, [GameCue.spawn]);
  });

  testWidgets('the real sound files load and play on this device', (
    tester,
  ) async {
    final real = DeviceFeedbackPlayer();
    await tester.runAsync(real.prepare);
    expect(real.ready, isTrue);
    real
      ..sound(GameCue.merge)
      ..haptic(HapticStrength.light);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    expect(tester.takeException(), isNull);
    // Nothing may still be playing when the test ends.
    await tester.runAsync(real.dispose);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
