import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/notification_prefs_repository.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';
import 'package:whispers_of_joppa/features/settings/notification_settings_screen.dart';
import 'package:whispers_of_joppa/features/settings/notifications_controller.dart';

import '../support/notification_fakes.dart';

const _config = EconomyConfig(
  maxManna: 100,
  mannaRegenSeconds: 120,
  generatorTapCost: 1,
  orderTalentsPerTier: 5,
  orderSlots: 3,
  tutorialFreeTaps: 12,
  mannaRefillBasePearls: 10,
  basketSlotBasePearls: 10,
  orderSkipCooldownSeconds: 1800,
  rewardedAdMannaBonus: 20,
  rewardedAdMannaDailyCap: 5,
  rewardedAdDoubleRewardDailyCap: 3,
);
const _content = testNotificationContent;

void main() {
  late FakeNotificationService service;
  late FakeDeviceTokenStore tokens;
  late NotificationPrefsRepository repository;
  final noon = DateTime(2026, 10, 6, 12);

  NotificationsController make() => NotificationsController(
    service: service,
    repository: repository,
    tokens: tokens,
    clock: () => noon,
  );

  Future<void> leave(NotificationsController c, {int manna = 0}) => c.onLeaving(
    content: _content,
    config: _config,
    manna: MannaState(manna: manna, lastRegen: noon),
  );

  setUp(() {
    service = FakeNotificationService();
    tokens = FakeDeviceTokenStore();
    repository = tempPrefsRepository();
  });

  test(
    'never asks before the chosen task, or before choices are read',
    () async {
      final c = make();
      expect(c.shouldAsk(_content, ['t5']), isFalse);
      await c.load();
      expect(c.shouldAsk(_content, ['t1']), isFalse);
      expect(c.shouldAsk(_content, ['t5']), isTrue);
      // Loading never brings up the phone's prompt.
      expect(service.prompts, 0);
    },
  );

  test('yes: the phone is asked, everything is on and remembered', () async {
    final c = make();
    await c.load();
    await c.answer(yes: true);
    expect(service.prompts, 1);
    expect(c.prefs.reminders && c.prefs.events && c.prefs.chapters, isTrue);
    expect(service.topicEvents, isTrue);
    expect(service.topicChapters, isTrue);
    expect(tokens.saved.single.$1, 'token-1');
    expect(c.shouldAsk(_content, ['t5']), isFalse);
    // A new launch reads the same choices and does not ask again.
    final again = make();
    await again.load();
    expect(again.prefs.reminders, isTrue);
    expect(again.shouldAsk(_content, ['t5']), isFalse);
  });

  test('no: the phone is never asked and nothing is scheduled', () async {
    final c = make();
    await c.load();
    await c.answer(yes: false);
    expect(service.prompts, 0);
    expect(c.prefs.anyOn, isFalse);
    expect(c.shouldAsk(_content, ['t5']), isFalse);
    await leave(c);
    expect(service.scheduled, isEmpty);
  });

  test('leaving schedules reminders; coming back clears them', () async {
    final c = make();
    await c.load();
    await c.answer(yes: true);
    await leave(c);
    expect(
      [for (final r in service.scheduled) r.id],
      [mannaFullReminderId, comeBackReminderId],
    );
    await c.onReturning();
    expect(service.scheduled, isEmpty);
  });

  test(
    'turning reminders off cancels them and keeps the other choices',
    () async {
      final c = make();
      await c.load();
      await c.answer(yes: true);
      await leave(c);
      await c.setReminders(false);
      expect(service.scheduled, isEmpty);
      expect(c.prefs.events, isTrue);
      await leave(c);
      expect(service.scheduled, isEmpty);
      await c.setEvents(false);
      expect(service.topicEvents, isFalse);
      expect(service.topicChapters, isTrue);
    },
  );

  test('turning one on later asks the phone then', () async {
    final c = make();
    await c.load();
    await c.answer(yes: false);
    await c.setChapters(true);
    expect(service.prompts, 1);
    expect(c.prefs.chapters, isTrue);
    expect(c.prefs.reminders, isFalse);
    expect(c.prefs.asked, isTrue);
  });

  test('says so when the phone itself blocks notifications', () async {
    service.allow = false;
    final c = make();
    await c.load();
    await c.answer(yes: true);
    expect(c.blockedByPhone, isTrue);
    // Allowed later in the phone's Settings: noticed on return.
    service.granted = true;
    await c.onReturning();
    expect(c.blockedByPhone, isFalse);
  });

  test('a server that cannot be reached does not undo the choice', () async {
    tokens.fail = true;
    final c = make();
    await c.load();
    await c.answer(yes: true);
    expect(c.prefs.reminders, isTrue);
  });

  testWidgets('the explainer returns the player\'s answer', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                answer = await showNotificationExplainer(context, _content),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('May we notify you?'), findsOneWidget);
    // A tap outside is not an answer: the question stays.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('May we notify you?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification_explainer_no')));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification_explainer_yes')));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('the settings screen shows and changes the three choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = make();
    await tester.runAsync(c.load);
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(controller: c, content: _content),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Gentle reminders'), findsOneWidget);
    expect(find.byKey(const Key('notifications_blocked')), findsNothing);
    service.allow = false;
    await tester.runAsync(() => c.setEvents(true));
    await tester.pump();
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('notify_events')))
          .value,
      isTrue,
    );
    expect(find.byKey(const Key('notifications_blocked')), findsOneWidget);
  });
}
