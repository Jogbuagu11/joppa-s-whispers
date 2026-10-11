// The goal events a player is in: what each has counted so far, and paying
// their rewards. Progress is kept in the save file under its own name.
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/goal_events.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

/// The name of the goal events' record in the save file.
const goalEventsRecord = 'goal_events';

/// A milestone just reached: which event, and what it paid.
typedef GoalPaid = ({GoalEvent event, PassReward reward});

class GoalEventsController extends ChangeNotifier {
  final SaveExtras extras;

  /// Which kinds are open to this player now (their level decides).
  final bool Function(GoalKind kind) open;

  /// Hands a reward to the player.
  final void Function(PassReward reward) grant;
  final Random _random;
  final DateTime Function() _now;
  List<GoalEvent> events;

  GoalEventsController({
    required this.events,
    required this.extras,
    required this.open,
    required this.grant,
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random(),
       _now = clock ?? DateTime.now;

  /// The events on now that this player may play, soonest to end first.
  List<GoalEvent> get live {
    final now = _now();
    return [
      for (final e in events)
        if (e.isLive(now) && open(e.kind)) e,
    ]..sort((a, b) => a.endsAt.compareTo(b.endsAt));
  }

  /// The latest milestones reached, for the screen to announce.
  final ValueNotifier<List<GoalPaid>> justPaid = ValueNotifier<List<GoalPaid>>(
    const [],
  );

  GoalProgress progressOf(GoalEvent event) =>
      GoalProgress.fromJson(extras.read(goalEventsRecord)?[event.id]);

  /// The freshest list from the server. Progress in events that are no
  /// longer listed is forgotten.
  void replaceEvents(List<GoalEvent> fresh) {
    events = fresh;
    final record = extras.read(goalEventsRecord);
    if (record != null) {
      final known = {for (final e in fresh) e.id};
      if (record.keys.any((id) => !known.contains(id))) {
        extras.write(goalEventsRecord, {
          for (final e in record.entries)
            if (known.contains(e.key)) e.key: e.value,
        });
      }
    }
    notifyListeners();
  }

  void orderDelivered(int talents) => _count(OrderDelivered(talents));
  void mannaSpent(int amount) => _count(MannaSpent(amount));
  void merged() => _count(ItemsMerged(_random.nextInt(100)));

  void _count(GoalAction action) {
    final paid = <GoalPaid>[];
    Map<String, dynamic>? record;
    for (final event in live) {
      final points = goalPoints(event, action);
      if (points == 0) continue;
      final before = progressOf(event);
      var after = GoalProgress(
        points: before.points + points,
        paid: before.paid,
      );
      final due = goalsToPay(event, after);
      // Counted as paid before anything is handed over.
      after = GoalProgress(points: after.points, paid: after.paid + due.length);
      (record ??= {...?extras.read(goalEventsRecord)})[event.id] = after
          .toJson();
      paid.addAll([for (final m in due) (event: event, reward: m.reward)]);
    }
    if (record == null) return;
    extras.write(goalEventsRecord, record);
    for (final p in paid) {
      grant(p.reward);
    }
    if (paid.isNotEmpty) justPaid.value = paid;
    notifyListeners();
  }

  @override
  void dispose() {
    justPaid.dispose();
    super.dispose();
  }
}
