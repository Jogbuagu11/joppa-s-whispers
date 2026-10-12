// Races: the townsfolk's pace, the player's place, and the prize.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/goal_event_validator.dart';
import 'package:whispers_of_joppa/domain/goal_events.dart';
import 'package:whispers_of_joppa/domain/race.dart';
import 'package:whispers_of_joppa/features/events/goal_events_controller.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

import '../support/goal_fixtures.dart';

Map<String, dynamic> _race([Map<String, dynamic> more = const {}]) => goalRow(
  id: 'race',
  type: 'race',
  more: {
    'goal': 3,
    'rivals': [
      {'name': 'Miriam', 'hours': 2},
      {'name': 'Tobias', 'hours': 4},
      {'name': 'Lydia', 'hours': 8},
      {'name': 'Reuben', 'hours': 20},
    ],
    'prizes': [
      {'pearls': 5},
      {'manna': 30},
      {'talents': 60},
    ],
    ...more,
  },
);

void main() {
  const rival = RaceRival(name: 'Miriam', hours: 2);

  test('a rival moves steadily and is home after their hours', () {
    expect(rivalCount(rival, 10, null), 0);
    expect(rivalCount(rival, 10, Duration.zero), 0);
    expect(rivalCount(rival, 10, const Duration(minutes: 60)), 5);
    expect(rivalCount(rival, 10, const Duration(minutes: 119)), 9);
    expect(rivalCount(rival, 10, const Duration(hours: 2)), 10);
    expect(rivalCount(rival, 10, const Duration(days: 9)), 10);
    expect(rivalCount(rival, 10, const Duration(hours: -1)), 0);
  });

  test('the place is one behind every rival already home', () {
    final event = GoalEvent.fromJson(_race());
    expect(racePlace(event.rivals, const Duration(hours: 1)), 1);
    expect(racePlace(event.rivals, const Duration(hours: 2)), 2);
    expect(racePlace(event.rivals, const Duration(hours: 5)), 3);
    expect(racePlace(event.rivals, const Duration(hours: 30)), 5);
  });

  test('a race is checked before it is played', () {
    expect(goalEventProblems(_race()), isEmpty);
    expect(playableGoalEvents([_race()]).single.raceGoal, 3);
    String problems(Map<String, dynamic> more) =>
        goalEventProblems(_race(more)).join('\n');
    expect(problems({'goal': 0}), contains('goal must be'));
    expect(problems({'rivals': <Object>[]}), contains('exactly 4 rivals'));
    expect(
      problems({
        'prizes': [
          {'pearls': 5},
        ],
      }),
      contains('3 prizes'),
    );
    // The fixture runs three days: a rival cannot take a week.
    expect(
      problems({
        'rivals': [
          {'name': 'A', 'hours': 2},
          {'name': 'B', 'hours': 4},
          {'name': 'C', 'hours': 8},
          {'name': 'D', 'hours': 200},
        ],
      }),
      contains('longer than the race lasts'),
    );
  });

  test('the first race in the database is sound', () {
    final sql = File(
      'supabase/migrations/20261011000006_first_race.sql',
    ).readAsStringSync();
    final config = RegExp(r"'(\{.*\})'::jsonb").firstMatch(sql)?.group(1);
    final row = goalRow(id: 'race_to_the_harbor_1', type: 'race')
      ..['config'] = jsonDecode(config ?? '');
    row['ends_at'] = DateTime.parse(
      row['starts_at'] as String,
    ).add(const Duration(days: 2)).toIso8601String();
    expect(goalEventProblems(row), isEmpty);
  });

  test('the race begins with the first order; the order that reaches the '
      'goal settles the place and pays its prize, once', () {
    var now = DateTime.now();
    final extras = SaveExtras();
    final paid = <int>[];
    final goals = GoalEventsController(
      events: playableGoalEvents([_race()]),
      extras: extras,
      open: (_) => true,
      grant: (reward) => paid.add(reward.manna),
      clock: () => now,
    );
    final event = goals.events.single;
    expect(goals.progressOf(event).joinedAt, isNull);
    goals.mannaSpent(50);
    goals.merged();
    expect(goals.progressOf(event).points, 0);
    goals.orderDelivered(40);
    final joined = goals.progressOf(event).joinedAt;
    expect(joined, isNotNull);
    now = now.add(const Duration(hours: 1));
    goals.orderDelivered(40);
    expect(goals.progressOf(event).place, 0);
    // Miriam (two hours) is home first.
    now = now.add(const Duration(hours: 2));
    goals.orderDelivered(40);
    expect(goals.progressOf(event).place, 2);
    expect(paid, [30]);
    goals.orderDelivered(40);
    expect(goals.progressOf(event).points, 3);
    expect(paid, [30]);
    goals.dispose();
  });

  test('a place outside the prizes pays nothing', () {
    final event = GoalEvent.fromJson(_race({'goal': 1}));
    final start = DateTime.utc(2026, 10, 12);
    final late = raceAfterOrder(
      event,
      GoalProgress(joinedAt: start),
      start.add(const Duration(hours: 9)),
    );
    expect(late.progress.place, 4);
    expect(late.prize, isNull);
    final read = GoalProgress.fromJson(
      jsonDecode(jsonEncode(late.progress.toJson())),
    );
    expect(read.place, 4);
    expect(read.joinedAt, start);
  });
}
