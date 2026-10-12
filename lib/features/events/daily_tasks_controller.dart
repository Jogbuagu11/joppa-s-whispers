// The player's daily tasks: what today's are, how far each has come, and
// paying their rewards. Kept in the save file under its own name.
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/daily_tasks.dart';
import 'package:whispers_of_joppa/domain/goal_events.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

/// The name of the daily tasks' record in the save file.
const dailyTasksRecord = 'daily_tasks';

class DailyTasksController extends ChangeNotifier {
  final DailyTasksConfig config;
  final SaveExtras extras;

  /// Whether daily tasks are open to this player now.
  final bool Function() open;

  /// Hands a reward to the player.
  final void Function(PassReward reward) grant;
  final DateTime Function() _now;

  DailyTasksController({
    required this.config,
    required this.extras,
    required this.open,
    required this.grant,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// The rewards just earned, for the screen to announce.
  final ValueNotifier<List<DailyPaid>> justPaid =
      ValueNotifier<List<DailyPaid>>(const []);

  /// Today's standing (a new day starts with nothing counted).
  DailyState get state =>
      dailyStateOn(DailyState.fromJson(extras.read(dailyTasksRecord)), _now());

  List<DailyTask> get today => tasksForDay(config, state.day);

  /// How many of today's tasks are done.
  int get doneToday => min(state.paid.length, today.length);

  Duration get untilNew => untilNextDay(_now());

  void orderDelivered(int talents) => _count(OrderDelivered(talents));
  void mannaSpent(int amount) => _count(MannaSpent(amount));
  void merged() => _count(const ItemsMerged(0));

  void _count(GoalAction action) {
    if (!open()) return;
    final before = state;
    final (state: after, :paid) = dailyAfter(config, before, action);
    if (identical(after, before)) return;
    // Recorded as paid before anything is handed over.
    extras.write(dailyTasksRecord, after.toJson());
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
