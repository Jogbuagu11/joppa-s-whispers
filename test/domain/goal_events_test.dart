// Goal events: what each kind counts, and which rewards are due.
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/goal_event_validator.dart';
import 'package:whispers_of_joppa/domain/goal_events.dart';

import '../support/event_fixtures.dart';
import '../support/goal_fixtures.dart';

GoalEvent _event(String type, [Map<String, dynamic> more = const {}]) =>
    GoalEvent.fromJson(goalRow(type: type, more: more));

void main() {
  test('each kind counts its own thing and nothing else', () {
    final milestone = _event('milestone');
    final energy = _event('energy');
    final collect = _event('collect', {'drop_percent': 25});
    final order = _event('order', {'per_order': 2});
    expect(goalPoints(milestone, const OrderDelivered(40)), 40);
    expect(goalPoints(milestone, const MannaSpent(5)), 0);
    expect(goalPoints(milestone, const ItemsMerged(0)), 0);
    expect(goalPoints(energy, const MannaSpent(5)), 5);
    expect(goalPoints(energy, const MannaSpent(-5)), 0);
    expect(goalPoints(energy, const OrderDelivered(40)), 0);
    expect(goalPoints(order, const OrderDelivered(40)), 2);
    // A token drops from a quarter of merges.
    expect(goalPoints(collect, const ItemsMerged(24)), 1);
    expect(goalPoints(collect, const ItemsMerged(25)), 0);
    expect(goalPoints(collect, const OrderDelivered(40)), 0);
  });

  test('milestones reached are due once; the next and the way to it', () {
    final event = _event('milestone');
    expect(goalsToPay(event, const GoalProgress(points: 9)), isEmpty);
    expect(goalsToPay(event, const GoalProgress(points: 35)).length, 2);
    expect(
      goalsToPay(event, const GoalProgress(points: 35, paid: 1)).single.points,
      30,
    );
    expect(goalsToPay(event, const GoalProgress(points: 35, paid: 2)), isEmpty);
    expect(goalsToPay(event, const GoalProgress(points: 35, paid: 9)), isEmpty);
    expect(nextGoal(event, const GoalProgress(points: 35))?.points, 60);
    expect(nextGoal(event, const GoalProgress(points: 60)), isNull);
    expect(goalFraction(event, const GoalProgress()), 0);
    expect(goalFraction(event, const GoalProgress(points: 5)), 0.5);
    expect(goalFraction(event, const GoalProgress(points: 20)), 0.5);
    expect(goalFraction(event, const GoalProgress(points: 99)), 1);
  });

  test('an event is on between its dates', () {
    final event = GoalEvent.fromJson(
      goalRow(
        startsAt: DateTime.utc(2026, 10, 10),
        endsAt: DateTime.utc(2026, 10, 13),
      ),
    );
    expect(event.isLive(DateTime.utc(2026, 10, 9, 23)), isFalse);
    expect(event.isLive(DateTime.utc(2026, 10, 10)), isTrue);
    expect(event.isLive(DateTime.utc(2026, 10, 13)), isFalse);
  });

  test('progress is kept in the save file; nonsense reads as nothing', () {
    const progress = GoalProgress(points: 35, paid: 2);
    final back = GoalProgress.fromJson(progress.toJson());
    expect(back.points, 35);
    expect(back.paid, 2);
    expect(GoalProgress.fromJson(null).points, 0);
    expect(GoalProgress.fromJson({'points': -4, 'paid': 'x'}).paid, 0);
  });

  test('a sound goal event has no problems; a board event is not one', () {
    expect(goalEventProblems(goalRow()), isEmpty);
    expect(isGoalEventRow(goalRow()), isTrue);
    expect(isGoalEventRow(eventRow()), isFalse);
    expect(isGoalEventRow('x'), isFalse);
    final rows = [eventRow(), goalRow(), goalRow(), goalRow(id: 'second')];
    expect(playableGoalEvents(rows).map((e) => e.id), ['harvest', 'second']);
  });

  test('mistakes in a goal event are caught, and it is left out', () {
    Map<String, dynamic> broken(Map<String, dynamic> more) =>
        goalRow(more: more);
    expect(goalEventProblems('x'), hasLength(1));
    expect(goalEventProblems(goalRow(id: 'Bad Id')).single, contains('id'));
    expect(
      goalEventProblems(
        goalRow(
          startsAt: DateTime.utc(2026, 10, 13),
          endsAt: DateTime.utc(2026, 10, 10),
        ),
      ).single,
      contains('end after'),
    );
    expect(goalEventProblems(broken({'blurb': ''})).single, contains('blurb'));
    expect(
      goalEventProblems(goalRow(type: 'collect')).single,
      contains('drop_percent'),
    );
    expect(
      goalEventProblems(goalRow(type: 'order', more: {'per_order': 0})).single,
      contains('per_order'),
    );
    expect(
      goalEventProblems(broken({'milestones': <dynamic>[]})).single,
      contains('at least one'),
    );
    expect(
      goalEventProblems(
        broken({
          'milestones': [
            {'points': 10, 'manna': 5},
            {'points': 10, 'manna': 5},
          ],
        }),
      ).single,
      contains('keep rising'),
    );
    expect(
      goalEventProblems(
        broken({
          'milestones': [
            {'points': 10},
          ],
        }),
      ).single,
      contains('nothing or too much'),
    );
    expect(
      goalEventProblems(
        broken({
          'milestones': [
            {'points': 10, 'pearls': 9999},
          ],
        }),
      ).single,
      contains('nothing or too much'),
    );
    final problems = <String>[];
    expect(
      playableGoalEvents([
        broken({'token': ''}),
      ], problems: problems.add),
      isEmpty,
    );
    expect(problems.single, contains('token'));
  });
}
