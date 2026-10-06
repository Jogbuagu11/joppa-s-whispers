// Milestone 20: the bell opens the notification switches, and nothing asks
// for permission until the player turns something on. The phone's
// notifications are a stand-in here: a test never schedules a real one.
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/features/settings/notifications_controller.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/notification_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('notification choices are the player\'s to make', (tester) async {
    final service = FakeNotificationService();
    final notifications = NotificationsController(
      service: service,
      repository: tempPrefsRepository(),
    );
    await SaveRepository().clear();
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          playOpeningScene: false,
          playTutorial: false,
          notifications: notifications,
        ),
      ),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    // The top row still fits with the bell added.
    expect(tester.takeException(), isNull);

    // Opening the game asks for nothing.
    expect(service.prompts, 0);
    expect(find.byKey(const Key('notification_explainer')), findsNothing);

    await tester.tap(find.byKey(const Key('notifications_button')));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byKey(const Key('notification_settings_screen')),
      findsOneWidget,
    );
    bool isOn(String key) =>
        tester.widget<SwitchListTile>(find.byKey(Key('notify_$key'))).value;
    expect(isOn('reminders'), isFalse);
    expect(isOn('events'), isFalse);
    expect(isOn('chapters'), isFalse);
    expect(service.prompts, 0);

    // Turning one on is what brings up the phone's own question.
    await tester.tap(find.byKey(const Key('notify_reminders')));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(service.prompts, 1);
    expect(isOn('reminders'), isTrue);
    expect(isOn('events'), isFalse);

    // And off again cancels any reminder.
    await tester.tap(find.byKey(const Key('notify_reminders')));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(isOn('reminders'), isFalse);
    expect(service.scheduled, isEmpty);
  });
}
