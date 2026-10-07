import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';
import 'package:whispers_of_joppa/features/settings/notification_settings_screen.dart';
import 'package:whispers_of_joppa/features/settings/notifications_controller.dart';

import '../support/comfort_fakes.dart';
import '../support/notification_fakes.dart';

void main() {
  late FakeFeedbackPlayer player;
  late Directory folder;

  setUp(() {
    player = FakeFeedbackPlayer();
    folder = Directory.systemTemp.createTempSync('comfort_test');
  });
  tearDown(() => folder.deleteSync(recursive: true));

  test('a cue plays its sound and its vibration', () async {
    final c = fakeComfort(player, folder: folder);
    await c.load();
    c.cue(GameCue.deliver);
    expect(player.sounds, [GameCue.deliver]);
    expect(player.haptics, [HapticStrength.heavy]);
  });

  test('loading gets the sounds ready, once', () async {
    final c = fakeComfort(player, folder: folder);
    await Future.wait([c.load(), c.load()]);
    expect(player.prepared, 1);
  });

  test('sound off: silent, but still vibrates', () async {
    final c = fakeComfort(player, folder: folder);
    await c.setSound(false);
    c.cue(GameCue.merge);
    expect(player.sounds, isEmpty);
    expect(player.haptics, [HapticStrength.medium]);
  });

  test('vibration off: still, but the sound plays', () async {
    final c = fakeComfort(player, folder: folder);
    await c.setHaptics(false);
    c.cue(GameCue.merge);
    expect(player.sounds, [GameCue.merge]);
    expect(player.haptics, isEmpty);
  });

  test('turning a switch on gives a taste of it; off gives nothing', () async {
    final c = fakeComfort(player, folder: folder);
    await c.setSound(false);
    await c.setHaptics(false);
    expect(player.sounds, isEmpty);
    expect(player.haptics, isEmpty);
    await c.setSound(true);
    await c.setHaptics(true);
    expect(player.sounds, [GameCue.merge]);
    expect(player.haptics, [HapticStrength.medium]);
  });

  test('choices are remembered the next time the game opens', () async {
    final first = fakeComfort(player, folder: folder);
    await first.setSound(false);
    await first.setTierNumbers(true);
    final second = fakeComfort(FakeFeedbackPlayer(), folder: folder);
    await second.load();
    expect(second.prefs.sound, isFalse);
    expect(second.prefs.haptics, isTrue);
    expect(second.prefs.tierNumbers, isTrue);
  });

  test('a damaged choices file means the usual choices, not a crash', () async {
    File('${folder.path}/comfort.json').writeAsStringSync('not json');
    final c = fakeComfort(player, folder: folder);
    await c.load();
    expect(c.prefs.sound, isTrue);
    expect(c.prefs.tierNumbers, isFalse);
  });

  testWidgets('the settings screen shows and changes the comfort switches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final comfort = fakeComfort(player, folder: folder);
    final notifications = NotificationsController(
      service: FakeNotificationService(),
      repository: tempPrefsRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: maxTextScale,
          maxScaleFactor: maxTextScale,
          child: NotificationSettingsScreen(
            controller: notifications,
            content: testNotificationContent,
            comfort: comfort,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Gentle reminders'), findsOneWidget);
    bool on(String key) =>
        tester.widget<SwitchListTile>(find.byKey(Key(key))).value;
    expect(on('comfort_sound'), isTrue);
    expect(on('comfort_tier_numbers'), isFalse);

    await tester.runAsync(() => comfort.setSound(false));
    await tester.runAsync(() => comfort.setTierNumbers(true));
    await tester.pump();
    expect(on('comfort_sound'), isFalse);
    expect(on('comfort_haptics'), isTrue);
    expect(on('comfort_tier_numbers'), isTrue);
  });
}
