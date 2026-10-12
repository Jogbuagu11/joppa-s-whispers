// Daily tasks (EXPANSION section 22): a few small goals each day, a chest
// for finishing them all, and a weekly chest for finishing enough days in
// one week. Pure Dart, fully unit tested.
//
// A day is the player's own calendar day; a week runs Monday to Sunday.
import 'package:whispers_of_joppa/domain/goal_events.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';

/// What a task counts, by its name in content/daily_tasks.json ("kind").
enum DailyKind { orders, talents, manna, merges }

const dailyKindNames = {
  'orders': DailyKind.orders,
  'talents': DailyKind.talents,
  'manna': DailyKind.manna,
  'merges': DailyKind.merges,
};

class DailyTask {
  final String id;
  final DailyKind kind;
  final int target;

  /// What to do, in words ("Deliver 3 orders").
  final String text;
  final PassReward reward;

  const DailyTask({
    required this.id,
    required this.kind,
    required this.target,
    required this.text,
    required this.reward,
  });
}

/// content/daily_tasks.json. (Check it with dailyTasksProblems first.)
class DailyTasksConfig {
  /// How many tasks a day has.
  final int perDay;

  /// Every task there is; each day takes [perDay] of them in turn.
  final List<DailyTask> pool;

  /// The chest for finishing all of a day's tasks.
  final PassReward chest;

  /// The weekly chest, for finishing this many days in one week.
  final int weeklyDays;
  final PassReward weekly;

  const DailyTasksConfig({
    required this.perDay,
    required this.pool,
    required this.chest,
    required this.weeklyDays,
    required this.weekly,
  });

  /// Null if there are no daily tasks (older content).
  static DailyTasksConfig? fromJson(Object? json) {
    if (json case {
      'per_day': final int perDay,
      'pool': final List<dynamic> pool,
      'weekly': {'days': final int weeklyDays, 'reward': final Object? weekly},
    }) {
      return DailyTasksConfig(
        perDay: perDay,
        chest: PassReward.fromJson(json['chest']),
        weeklyDays: weeklyDays,
        weekly: PassReward.fromJson(weekly),
        pool: [
          for (final t in pool)
            if (t case {
              'id': final String id,
              'kind': final String kind,
              'target': final int target,
              'text': final String text,
            } when dailyKindNames.containsKey(kind))
              DailyTask(
                id: id,
                // Safe: the line above has checked the kind is one of these.
                kind: dailyKindNames[kind]!,
                target: target,
                text: text,
                reward: PassReward.fromJson(t['reward']),
              ),
        ],
      );
    }
    return null;
  }
}

/// The number of the calendar day [now] falls on (the same for every moment
/// of one day on the player's own calendar, one more each day).
int dayNumber(DateTime now) =>
    DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// The day number of the Monday of [day]'s week.
int weekOf(int day) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    day * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return day - (date.weekday - DateTime.monday);
}

/// The tasks of [day]: the next few of the pool, going round it, so that
/// each day differs from the one before.
List<DailyTask> tasksForDay(DailyTasksConfig config, int day) {
  final pool = config.pool;
  if (pool.isEmpty || config.perDay <= 0) return const [];
  final count = config.perDay < pool.length ? config.perDay : pool.length;
  final start = (day * count) % pool.length;
  return [for (int i = 0; i < count; i++) pool[(start + i) % pool.length]];
}

/// A player's daily tasks, as kept in the save file.
class DailyState {
  /// The day these counts are for.
  final int day;

  /// Task id -> how much of it has been done today.
  final Map<String, int> counts;

  /// The tasks whose rewards have been paid today.
  final Set<String> paid;

  /// Whether today's chest has been paid.
  final bool chest;

  /// The week (see weekOf) [daysDone] counts, and whether its chest has
  /// been paid.
  final int week;
  final int daysDone;
  final bool weekPaid;

  const DailyState({
    this.day = 0,
    this.counts = const {},
    this.paid = const {},
    this.chest = false,
    this.week = 0,
    this.daysDone = 0,
    this.weekPaid = false,
  });

  /// Reads the saved record; anything odd in it counts as nothing.
  factory DailyState.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const DailyState();
    int count(Object? value) => value is int && value > 0 ? value : 0;
    return DailyState(
      day: count(json['day']),
      counts: {
        if (json['counts'] case final Map<String, dynamic> counts)
          for (final e in counts.entries)
            if (count(e.value) > 0) e.key: count(e.value),
      },
      paid: {
        if (json['paid'] case final List<dynamic> ids)
          for (final id in ids)
            if (id is String) id,
      },
      chest: json['chest'] == true,
      week: count(json['week']),
      daysDone: count(json['days_done']),
      weekPaid: json['week_paid'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'counts': counts,
    'paid': paid.toList(),
    'chest': chest,
    'week': week,
    'days_done': daysDone,
    'week_paid': weekPaid,
  };
}

/// [saved] as it stands on the day of [now]: a new day starts with nothing
/// counted, and a new week with no days done. A clock put back changes
/// nothing: the day already begun goes on until the calendar reaches it.
DailyState dailyStateOn(DailyState saved, DateTime now) {
  final today = dayNumber(now);
  if (today <= saved.day) return saved;
  final sameWeek = weekOf(today) == saved.week;
  return DailyState(
    day: today,
    week: weekOf(today),
    daysDone: sameWeek ? saved.daysDone : 0,
    weekPaid: sameWeek && saved.weekPaid,
  );
}

/// How much [action] adds to a task of [kind].
int dailyPoints(DailyKind kind, GoalAction action) {
  final points = switch ((kind, action)) {
    (DailyKind.orders, OrderDelivered()) => 1,
    (DailyKind.talents, OrderDelivered(:final talents)) => talents,
    (DailyKind.manna, MannaSpent(:final amount)) => amount,
    (DailyKind.merges, ItemsMerged()) => 1,
    _ => 0,
  };
  return points < 0 ? 0 : points;
}

/// What a reward was for.
enum DailyPrize { task, chest, weekly }

typedef DailyPaid = ({DailyPrize prize, PassReward reward});

/// [state] (already brought to today with dailyStateOn) after [action],
/// and the rewards that fall due: each task's once, the day's chest once
/// when every task is done, the weekly chest once when enough days are.
({DailyState state, List<DailyPaid> paid}) dailyAfter(
  DailyTasksConfig config,
  DailyState state,
  GoalAction action,
) {
  final tasks = tasksForDay(config, state.day);
  final counts = {...state.counts};
  final paid = {...state.paid};
  final due = <DailyPaid>[];
  var changed = false;
  for (final task in tasks) {
    final points = dailyPoints(task.kind, action);
    final before = counts[task.id] ?? 0;
    if (points == 0 || before >= task.target) continue;
    final now = before + points > task.target ? task.target : before + points;
    counts[task.id] = now;
    changed = true;
    if (now >= task.target && paid.add(task.id)) {
      due.add((prize: DailyPrize.task, reward: task.reward));
    }
  }
  if (!changed) return (state: state, paid: const []);
  var chest = state.chest;
  var daysDone = state.daysDone;
  var weekPaid = state.weekPaid;
  if (!chest && tasks.every((t) => paid.contains(t.id))) {
    chest = true;
    daysDone++;
    due.add((prize: DailyPrize.chest, reward: config.chest));
    if (!weekPaid && daysDone >= config.weeklyDays) {
      weekPaid = true;
      due.add((prize: DailyPrize.weekly, reward: config.weekly));
    }
  }
  return (
    state: DailyState(
      day: state.day,
      counts: counts,
      paid: paid,
      chest: chest,
      week: state.week,
      daysDone: daysDone,
      weekPaid: weekPaid,
    ),
    paid: due,
  );
}

/// How long until the day of [now] ends and new tasks come.
Duration untilNextDay(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1).difference(now);
