import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';

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
  final noon = DateTime(2026, 10, 6, 12);

  group('quiet hours (9 pm to 9 am)', () {
    test('which hours are quiet', () {
      expect(isQuietHour(21, 21, 9), isTrue);
      expect(isQuietHour(23, 21, 9), isTrue);
      expect(isQuietHour(0, 21, 9), isTrue);
      expect(isQuietHour(8, 21, 9), isTrue);
      expect(isQuietHour(9, 21, 9), isFalse);
      expect(isQuietHour(20, 21, 9), isFalse);
    });

    test('a daytime range and an empty range also work', () {
      expect(isQuietHour(13, 12, 14), isTrue);
      expect(isQuietHour(14, 12, 14), isFalse);
      expect(isQuietHour(3, 9, 9), isFalse);
    });

    test('a daytime moment is left alone', () {
      expect(afterQuietHours(noon, 21, 9), noon);
    });

    test('late evening moves to 9 the next morning', () {
      expect(
        afterQuietHours(DateTime(2026, 10, 6, 22, 30), 21, 9),
        DateTime(2026, 10, 7, 9),
      );
    });

    test('the small hours move to 9 the same morning', () {
      expect(
        afterQuietHours(DateTime(2026, 10, 6, 3, 15), 21, 9),
        DateTime(2026, 10, 6, 9),
      );
    });
  });

  group('mannaFullAt', () {
    test('a low bar fills at the regen rate', () {
      final state = MannaState(manna: 10, lastRegen: noon);
      expect(
        mannaFullAt(_config, state, noon, lowPercent: 20),
        noon.add(const Duration(seconds: 90 * 120)),
      );
    });

    test('no reminder if the player was not low', () {
      final state = MannaState(manna: 21, lastRegen: noon);
      expect(mannaFullAt(_config, state, noon, lowPercent: 20), isNull);
      final edge = MannaState(manna: 20, lastRegen: noon);
      expect(mannaFullAt(_config, edge, noon, lowPercent: 20), isNotNull);
    });

    test('no reminder if the bar is full or over', () {
      final state = MannaState(manna: 140, lastRegen: noon);
      expect(mannaFullAt(_config, state, noon, lowPercent: 20), isNull);
    });

    test('no reminder for a moment already past', () {
      final state = MannaState(
        manna: 0,
        lastRegen: noon.subtract(const Duration(days: 2)),
      );
      expect(mannaFullAt(_config, state, noon, lowPercent: 20), isNull);
    });
  });

  group('planReminders', () {
    final low = MannaState(manna: 0, lastRegen: noon);

    List<PlannedReminder> plan(NotificationPrefs prefs, {MannaState? manna}) =>
        planReminders(
          prefs: prefs,
          content: _content,
          config: _config,
          manna: manna ?? low,
          now: noon,
        );

    test('nothing is scheduled when reminders are off', () {
      expect(plan(const NotificationPrefs()), isEmpty);
      expect(plan(const NotificationPrefs.declined()), isEmpty);
      expect(
        plan(const NotificationPrefs.allOn().copyWith(reminders: false)),
        isEmpty,
      );
    });

    test('low Manna schedules Manna-full and one come-back reminder', () {
      final planned = plan(const NotificationPrefs.allOn());
      expect(
        [for (final p in planned) p.id],
        [mannaFullReminderId, comeBackReminderId],
      );
      // 100 Manna at 2 minutes each from noon is 3:20 pm.
      expect(planned.first.when, DateTime(2026, 10, 6, 15, 20));
      expect(planned.first.title, 'Manna full');
      expect(planned.last.when, DateTime(2026, 10, 9, 12));
    });

    test('with enough Manna only the come-back reminder is scheduled', () {
      final planned = plan(
        const NotificationPrefs.allOn(),
        manna: MannaState(manna: 80, lastRegen: noon),
      );
      expect([for (final p in planned) p.id], [comeBackReminderId]);
    });

    test('nothing is ever scheduled in the quiet hours', () {
      final evening = DateTime(2026, 10, 6, 19);
      final planned = planReminders(
        prefs: const NotificationPrefs.allOn(),
        content: _content,
        config: _config,
        manna: MannaState(manna: 0, lastRegen: evening),
        now: evening,
      );
      // Full at 10:20 pm, so it waits until 9 the next morning.
      expect(planned.first.when, DateTime(2026, 10, 7, 9));
      for (final p in planned) {
        expect(isQuietHour(p.when.hour, 21, 9), isFalse);
      }
    });
  });

  group('times that arrive as UTC (as a loaded save gives them)', () {
    test('quiet hours go by the phone\'s clock, not UTC', () {
      final lateLocal = DateTime(2026, 10, 6, 22, 30);
      expect(
        afterQuietHours(lateLocal.toUtc(), 21, 9),
        DateTime(2026, 10, 7, 9),
      );
      expect(afterQuietHours(noon.toUtc(), 21, 9), noon);
    });

    test('a Manna-full time from a saved game still avoids the night', () {
      final evening = DateTime(2026, 10, 6, 19);
      final planned = planReminders(
        prefs: const NotificationPrefs.allOn(),
        content: _content,
        config: _config,
        manna: MannaState(manna: 0, lastRegen: evening.toUtc()),
        now: evening,
      );
      expect(planned.first.when, DateTime(2026, 10, 7, 9));
    });
  });

  group('comeBackTime', () {
    test('three days after leaving when none was shown before', () {
      expect(
        comeBackTime(noon, afterDays: 3, repeatDays: 7),
        DateTime(2026, 10, 9, 12),
      );
    });

    test(
      'one that never showed (the player came back first) does not count',
      () {
        expect(
          comeBackTime(
            noon,
            afterDays: 3,
            repeatDays: 7,
            lastShown: noon.add(const Duration(days: 2)),
          ),
          DateTime(2026, 10, 9, 12),
        );
      },
    );

    test('never within a week of one already shown', () {
      final shown = noon.subtract(const Duration(days: 1));
      expect(
        comeBackTime(noon, afterDays: 3, repeatDays: 7, lastShown: shown),
        shown.add(const Duration(days: 7)),
      );
      final longAgo = noon.subtract(const Duration(days: 30));
      expect(
        comeBackTime(noon, afterDays: 3, repeatDays: 7, lastShown: longAgo),
        DateTime(2026, 10, 9, 12),
      );
    });
  });

  group('the in-game question', () {
    test('asked once, only after the chosen task', () {
      const fresh = NotificationPrefs();
      expect(shouldAskAboutNotifications(fresh, _content, ['t1']), isFalse);
      expect(
        shouldAskAboutNotifications(fresh, _content, ['t1', 't5']),
        isTrue,
      );
      expect(
        shouldAskAboutNotifications(
          const NotificationPrefs.declined(),
          _content,
          ['t5'],
        ),
        isFalse,
      );
      expect(
        shouldAskAboutNotifications(const NotificationPrefs.allOn(), _content, [
          't5',
        ]),
        isFalse,
      );
    });
  });

  test('choices survive being saved and read back', () {
    final prefs = const NotificationPrefs.allOn()
        .copyWith(events: false)
        .withComeBackAt(noon);
    final back = NotificationPrefs.fromJson(prefs.toJson());
    expect(back.comeBackAt, noon);
    expect(back.asked, isTrue);
    expect(back.reminders, isTrue);
    expect(back.events, isFalse);
    expect(back.chapters, isTrue);
    // A damaged file reads as "everything off, never asked".
    final empty = NotificationPrefs.fromJson({'reminders': 'yes'});
    expect(empty.asked, isFalse);
    expect(empty.anyOn, isFalse);
  });
}
