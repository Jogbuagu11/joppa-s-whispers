// Daily tasks: which tasks a day has, counting, and the three rewards.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/daily_tasks_validator.dart';
import 'package:whispers_of_joppa/domain/daily_tasks.dart';
import 'package:whispers_of_joppa/domain/goal_events.dart';
import 'package:whispers_of_joppa/features/events/daily_tasks_controller.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

Map<String, dynamic> _json({int perDay = 2, int days = 2}) => {
  'per_day': perDay,
  'pool': [
    {
      'id': 'a',
      'kind': 'orders',
      'target': 2,
      'text': 'A',
      'reward': {'talents': 5},
    },
    {
      'id': 'b',
      'kind': 'merges',
      'target': 1,
      'text': 'B',
      'reward': {'manna': 3},
    },
    {
      'id': 'c',
      'kind': 'manna',
      'target': 10,
      'text': 'C',
      'reward': {'talents': 7},
    },
    {
      'id': 'd',
      'kind': 'talents',
      'target': 30,
      'text': 'D',
      'reward': {'manna': 4},
    },
  ],
  'chest': {'talents': 50},
  'weekly': {
    'days': days,
    'reward': {'pearls': 10},
  },
};

void main() {
  // Safe: the fixture above is complete.
  final config = DailyTasksConfig.fromJson(_json())!;
  // A Monday.
  final monday = DateTime(2026, 10, 12, 9);

  test('a day has the next few tasks of the pool, the same all day', () {
    final day = dayNumber(monday);
    final first = [for (final t in tasksForDay(config, day)) t.id];
    expect(first.length, 2);
    expect([
      for (final t in tasksForDay(
        config,
        dayNumber(DateTime(2026, 10, 12, 23)),
      ))
        t.id,
    ], first);
    final next = [for (final t in tasksForDay(config, day + 1)) t.id];
    expect(next, isNot(first));
    expect(first.toSet().length, 2);
    // Never more than the pool holds.
    final small = DailyTasksConfig.fromJson(_json(perDay: 9))!;
    expect(tasksForDay(small, day).length, 4);
  });

  test('a week runs Monday to Sunday', () {
    final day = dayNumber(monday);
    expect(weekOf(day), day);
    expect(weekOf(day + 6), day);
    expect(weekOf(day + 7), day + 7);
    expect(weekOf(day - 1), day - 7);
  });

  test('each kind counts its own thing', () {
    expect(dailyPoints(DailyKind.orders, const OrderDelivered(40)), 1);
    expect(dailyPoints(DailyKind.talents, const OrderDelivered(40)), 40);
    expect(dailyPoints(DailyKind.manna, const MannaSpent(3)), 3);
    expect(dailyPoints(DailyKind.merges, const ItemsMerged(0)), 1);
    expect(dailyPoints(DailyKind.merges, const MannaSpent(3)), 0);
    expect(dailyPoints(DailyKind.manna, const MannaSpent(-3)), 0);
  });

  test('tasks pay once, then the chest, then the weekly chest', () {
    final all = DailyTasksConfig.fromJson(_json(perDay: 4, days: 2))!;
    var state = dailyStateOn(const DailyState(), monday);
    final got = <DailyPrize>[];
    void act(GoalAction action) {
      final result = dailyAfter(all, state, action);
      state = result.state;
      got.addAll([for (final p in result.paid) p.prize]);
    }

    act(const OrderDelivered(30));
    expect(got, [DailyPrize.task]); // 30 Talents
    expect(state.counts['a'], 1);
    act(const OrderDelivered(30));
    act(const ItemsMerged(0));
    act(const ItemsMerged(0));
    expect(state.counts['b'], 1);
    act(const MannaSpent(25));
    expect(state.counts['c'], 10);
    expect(got, [
      DailyPrize.task,
      DailyPrize.task,
      DailyPrize.task,
      DailyPrize.task,
      DailyPrize.chest,
    ]);
    expect(state.daysDone, 1);
    // Nothing more today.
    final again = dailyAfter(all, state, const OrderDelivered(30));
    expect(again.paid, isEmpty);
    expect(identical(again.state, state), isTrue);

    // The next day starts clean and its chest brings the weekly one.
    state = dailyStateOn(state, monday.add(const Duration(days: 1)));
    expect(state.counts, isEmpty);
    expect(state.chest, isFalse);
    got.clear();
    act(const OrderDelivered(30));
    act(const OrderDelivered(30));
    act(const ItemsMerged(0));
    act(const MannaSpent(10));
    expect(got.last, DailyPrize.weekly);
    expect(state.weekPaid, isTrue);
    // A third day in the same week: no second weekly chest.
    state = dailyStateOn(state, monday.add(const Duration(days: 2)));
    expect(state.weekPaid, isTrue);
    // A new week forgets the days done.
    state = dailyStateOn(state, monday.add(const Duration(days: 7)));
    expect(state.daysDone, 0);
    expect(state.weekPaid, isFalse);
  });

  test('a clock put back does not bring new tasks', () {
    final state = dailyStateOn(const DailyState(), monday);
    final back = dailyStateOn(state, monday.subtract(const Duration(days: 3)));
    expect(identical(back, state), isTrue);
  });

  test('the saved record is read carefully and survives a round trip', () {
    expect(DailyState.fromJson('x').day, 0);
    final odd = DailyState.fromJson(<String, dynamic>{
      'day': -4,
      'counts': {'a': 2, 'b': 'x'},
      'paid': ['a', 3],
      'chest': 'yes',
    });
    expect(odd.day, 0);
    expect(odd.counts, {'a': 2});
    expect(odd.paid, {'a'});
    expect(odd.chest, isFalse);
    const state = DailyState(
      day: 9,
      counts: {'a': 1},
      paid: {'b'},
      chest: true,
      week: 7,
      daysDone: 2,
      weekPaid: true,
    );
    final read = DailyState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
    );
    expect(read.toJson(), state.toJson());
    expect(untilNextDay(monday), const Duration(hours: 15));
  });

  test('the controller counts only while open, pays, and saves', () {
    final extras = SaveExtras();
    var open = false;
    var talents = 0;
    var now = monday;
    final daily = DailyTasksController(
      config: DailyTasksConfig.fromJson(_json(perDay: 4))!,
      extras: extras,
      open: () => open,
      grant: (reward) => talents += reward.talents,
      clock: () => now,
    );
    daily.orderDelivered(30);
    expect(extras.read(dailyTasksRecord), isNull);
    open = true;
    daily.orderDelivered(30);
    daily.orderDelivered(30);
    expect(talents, 5);
    expect(daily.doneToday, 2);
    expect(daily.justPaid.value.length, 1);
    daily.merged();
    daily.mannaSpent(10);
    expect(talents, 5 + 7 + 50);
    expect(daily.state.chest, isTrue);
    now = monday.add(const Duration(days: 1));
    expect(daily.doneToday, 0);
    daily.dispose();
  });

  test('the game\'s own daily tasks are sound, and mistakes are named', () {
    Object? read(String name) =>
        jsonDecode(File('content/$name.json').readAsStringSync());
    final ids = itemIdsOf(read('chains'));
    final real = read('daily_tasks');
    expect(dailyTasksProblems(real, itemIds: ids), isEmpty);
    expect(DailyTasksConfig.fromJson(real)?.pool.length, 12);
    expect(dailyTasksProblems(null, itemIds: ids), isNotEmpty);
    final bad = Map<String, dynamic>.of(real as Map<String, dynamic>)
      ..['per_day'] = 40
      ..['chest'] = {'pearls': 9999}
      ..['weekly'] = {
        'days': 9,
        'reward': {
          'items': ['no_such_item'],
        },
      }
      ..['text'] = {'chest': 'no places'};
    final problems = dailyTasksProblems(bad, itemIds: ids).join('\n');
    expect(problems, contains('per_day'));
    expect(problems, contains('the chest gives a wrong amount of pearls'));
    expect(problems, contains('weekly days'));
    expect(problems, contains('unknown item'));
    expect(problems, contains('text "chest" must contain'));
    expect(problems, contains('text "title" is missing'));
  });
}
