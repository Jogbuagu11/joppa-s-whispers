// Goal events in play: counting, paying each milestone once, and keeping
// progress in the save.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/goal_events.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/goal_events_controller.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

import '../support/goal_fixtures.dart';

/// Luck that always rolls the same number.
class _Roll implements Random {
  _Roll(this.value);
  int value;
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => value;
}

void main() {
  final harvest = GoalEvent.fromJson(goalRow());
  final energy = GoalEvent.fromJson(goalRow(id: 'energy', type: 'energy'));
  final collect = GoalEvent.fromJson(
    goalRow(id: 'collect', type: 'collect', more: {'drop_percent': 50}),
  );
  final over = GoalEvent.fromJson(
    goalRow(
      id: 'over',
      startsAt: DateTime.utc(2020),
      endsAt: DateTime.utc(2020, 1, 3),
    ),
  );
  late SaveExtras extras;
  late List<PassReward> given;
  late Set<GoalKind> closed;
  late _Roll roll;

  GoalEventsController make(List<GoalEvent> events) => GoalEventsController(
    events: events,
    extras: extras,
    open: (kind) => !closed.contains(kind),
    grant: given.add,
    random: roll,
  );

  setUp(() {
    extras = SaveExtras();
    given = [];
    closed = {};
    roll = _Roll(0);
  });
  tearDown(() => extras.dispose());

  test('only events that are on, and open to the player, are played', () {
    final c = make([harvest, energy, over]);
    expect(c.live.map((e) => e.id), unorderedEquals(['harvest', 'energy']));
    closed.add(GoalKind.energy);
    expect(c.live.single.id, 'harvest');
    c.mannaSpent(50);
    expect(c.progressOf(energy).points, 0);
    c.dispose();
  });

  test('orders, Manna and merges are counted by the events that count them, '
      'several at once', () {
    final c = make([harvest, energy, collect])
      ..orderDelivered(12)
      ..mannaSpent(4)
      ..merged();
    expect(c.progressOf(harvest).points, 12);
    expect(c.progressOf(energy).points, 4);
    expect(c.progressOf(collect).points, 1);
    // An unlucky merge drops nothing.
    roll.value = 80;
    c.merged();
    expect(c.progressOf(collect).points, 1);
    c.dispose();
  });

  test('each milestone pays once, also when several are passed at a stride, '
      'and is announced', () {
    final c = make([harvest])..orderDelivered(12);
    expect(given.single.manna, 5);
    expect(c.justPaid.value.single.event.id, 'harvest');
    c.orderDelivered(3);
    expect(given.length, 1);
    c.orderDelivered(100);
    expect(given.length, 3);
    expect(given[1].pearls, 2);
    expect(given[2].items, ['thread_01']);
    expect(c.progressOf(harvest).paid, 3);
    c.orderDelivered(100);
    expect(given.length, 3);
    c.dispose();
  });

  test('progress is in the save, and a fresh game carries on from it', () {
    make([harvest])
      ..orderDelivered(12)
      ..dispose();
    final again = make([harvest]);
    expect(again.progressOf(harvest).points, 12);
    again.orderDelivered(1);
    // The first milestone is not paid a second time.
    expect(given.length, 1);
    again.dispose();
  });

  test('an event that drops off the server\'s list for a while keeps the '
      'player\'s place: nothing is earned twice', () {
    final c = make([harvest, energy])
      ..orderDelivered(12)
      ..mannaSpent(4)
      // Switched off to be corrected: not listed, not over.
      ..replaceEvents([energy]);
    expect(c.live.single.id, 'energy');
    expect(extras.read(goalEventsRecord)?.keys, ['harvest', 'energy']);
    c.replaceEvents([harvest, energy]);
    expect(c.progressOf(harvest).points, 12);
    c.orderDelivered(1);
    expect(given.length, 1);
    c.dispose();
  });

  test('progress in an event that is over and no longer listed is '
      'forgotten', () {
    var now = DateTime.now();
    final c = GoalEventsController(
      events: [harvest],
      extras: extras,
      open: (_) => true,
      grant: given.add,
      clock: () => now,
    )..orderDelivered(12);
    now = now.add(const Duration(days: 30));
    c.replaceEvents(const []);
    expect(extras.read(goalEventsRecord), isEmpty);
    c.dispose();
  });

  test('nothing is written when nothing is counted', () {
    var writes = 0;
    extras.addListener(() => writes++);
    final c = make([harvest])..mannaSpent(9);
    expect(writes, 0);
    c.dispose();
  });
}
