// The goal events a player is in: what each has counted so far, and paying
// their rewards. Progress is kept in the save file under its own name.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/global_goal.dart';
import 'package:whispers_of_joppa/domain/goal_events.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

/// The name of the goal events' record in the save file.
const goalEventsRecord = 'goal_events';

/// The name of the record of the player's part in global goals.
const globalGoalsRecord = 'global_goals';

final _log = Logger('GoalEvents');

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

  /// The server's count for global goals; null where there is none.
  final GlobalGoalServer? server;

  GoalEventsController({
    required this.events,
    required this.extras,
    required this.open,
    required this.grant,
    this.server,
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

  GoalProgress progressOf(GoalEvent event) => event.kind == GoalKind.global
      ? globalOf(event).shown
      : GoalProgress.fromJson(extras.read(goalEventsRecord)?[event.id]);

  /// The player's part in a global goal.
  GlobalProgress globalOf(GoalEvent event) =>
      GlobalProgress.fromJson(extras.read(globalGoalsRecord)?[event.id]);

  void _keepGlobal(GoalEvent event, GlobalProgress progress) => extras.write(
    globalGoalsRecord,
    {...?extras.read(globalGoalsRecord), event.id: progress.toJson()},
  );

  /// Pays the milestones a global goal has reached (counted as paid before
  /// anything is handed over).
  void _payGlobal(GoalEvent event) {
    final progress = globalOf(event);
    final due = globalToPay(event, progress);
    if (due.isEmpty) return;
    _keepGlobal(event, progress.copyWith(paid: progress.paid + due.length));
    for (final m in due) {
      grant(m.reward);
    }
    justPaid.value = [for (final m in due) (event: event, reward: m.reward)];
  }

  bool _syncing = false;

  /// Tells the server of this player's orders in the global goals that are
  /// on, hears the totals, and pays what they have reached. Never throws.
  Future<void> syncGlobal() async {
    final source = server;
    if (source == null || _syncing) return;
    _syncing = true;
    try {
      for (final event in live.where((e) => e.kind == GoalKind.global)) {
        final amount = source.signedIn ? globalOf(event).toSend : 0;
        final total = amount > 0
            ? await source.add(event.id, amount)
            : await source.total(event.id);
        if (_disposed) return;
        // Read again: orders may have been delivered meanwhile.
        final now = globalOf(event);
        _keepGlobal(
          event,
          GlobalProgress(
            mine: now.mine,
            sent: now.sent + amount,
            total: total > now.total ? total : now.total,
            paid: now.paid,
            endsAt: event.endsAt,
          ),
        );
        _payGlobal(event);
      }
      notifyListeners();
    } on Object catch (e) {
      _log.info('Global goal not synced: $e');
    } finally {
      _syncing = false;
    }
  }

  bool _disposed = false;

  /// The freshest list from the server. Progress is forgotten only for
  /// events that are no longer listed AND whose end has passed.
  void replaceEvents(List<GoalEvent> fresh) {
    events = fresh;
    final record = extras.read(goalEventsRecord);
    if (record != null) {
      final kept = goalProgressToKeep(record, {
        for (final e in fresh) e.id,
      }, _now());
      if (kept.length != record.length) extras.write(goalEventsRecord, kept);
    }
    final global = extras.read(globalGoalsRecord);
    if (global != null) {
      final kept = goalProgressToKeep(global, {
        for (final e in fresh) e.id,
      }, _now());
      if (kept.length != global.length) extras.write(globalGoalsRecord, kept);
    }
    unawaited(syncGlobal());
    notifyListeners();
  }

  void orderDelivered(int talents) => _count(OrderDelivered(talents));
  void mannaSpent(int amount) => _count(MannaSpent(amount));
  void merged() => _count(ItemsMerged(_random.nextInt(100)));

  void _count(GoalAction action) {
    final paid = <GoalPaid>[];
    Map<String, dynamic>? record;
    var global = false;
    for (final event in live) {
      if (event.kind == GoalKind.global) {
        if (action is! OrderDelivered) continue;
        final mine = globalOf(event);
        _keepGlobal(
          event,
          GlobalProgress(
            mine: mine.mine + 1,
            sent: mine.sent,
            total: mine.total,
            paid: mine.paid,
            endsAt: event.endsAt,
          ),
        );
        _payGlobal(event);
        global = true;
        continue;
      }
      final points = goalPoints(event, action);
      if (points == 0) continue;
      final before = progressOf(event);
      if (event.kind == GoalKind.race) {
        final (:progress, :prize) = raceAfterOrder(event, before, _now());
        if (identical(progress, before)) continue;
        (record ??= {...?extras.read(goalEventsRecord)})[event.id] = progress
            .toJson();
        if (prize != null) paid.add((event: event, reward: prize));
        continue;
      }
      var after = GoalProgress(
        points: before.points + points,
        paid: before.paid,
      );
      final due = goalsToPay(event, after);
      // Counted as paid before anything is handed over.
      after = GoalProgress(
        points: after.points,
        paid: after.paid + due.length,
        endsAt: event.endsAt,
      );
      (record ??= {...?extras.read(goalEventsRecord)})[event.id] = after
          .toJson();
      paid.addAll([for (final m in due) (event: event, reward: m.reward)]);
    }
    if (global) {
      notifyListeners();
      unawaited(syncGlobal());
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
    _disposed = true;
    justPaid.dispose();
    super.dispose();
  }
}
