// Checks a goal event before the game will show it. Events come from the
// server, so a mistake in one must be caught here, never crash the game.
// Pure Dart.
import 'package:whispers_of_joppa/domain/goal_events.dart';

// No single milestone gives more than this, whatever a slip of the finger
// says.
const _most = {'pearls': 100, 'manna': 500, 'talents': 5000};

/// Plain-English problems with one goal event ({id, name, starts_at,
/// ends_at, config}). An empty list means it can be played.
List<String> goalEventProblems(Object? raw) {
  if (raw is! Map<String, dynamic>) return ['Event is not an object'];
  final problems = <String>[];
  final id = raw['id'];
  final label = 'Event "$id"';
  if (id is! String || !RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(id)) {
    problems.add('$label: id must be lowercase letters, digits and _');
  }
  final name = raw['name'];
  if (name is! String || name.trim().isEmpty || name.length > 40) {
    problems.add('$label: name must be 1 to 40 characters');
  }
  final start = DateTime.tryParse('${raw['starts_at']}');
  final end = DateTime.tryParse('${raw['ends_at']}');
  if (start == null || end == null) {
    problems.add('$label: starts_at and ends_at must be dates');
  } else if (!end.isAfter(start)) {
    problems.add('$label: must end after it starts');
  }
  final config = raw['config'];
  if (config is! Map<String, dynamic>) {
    return [...problems, '$label: no settings'];
  }
  final kind = goalKindNames[config['type']];
  if (kind == null) return [...problems, '$label: unknown type'];
  for (final key in const ['blurb', 'token']) {
    final words = config[key];
    if (words is! String || words.trim().isEmpty || words.length > 120) {
      problems.add('$label: "$key" must be 1 to 120 characters');
    }
  }
  final drop = config['drop_percent'];
  if (kind == GoalKind.collect && (drop is! int || drop < 1 || drop > 100)) {
    problems.add('$label: drop_percent must be 1 to 100');
  }
  final perOrder = config['per_order'] ?? 1;
  if (kind == GoalKind.order &&
      (perOrder is! int || perOrder < 1 || perOrder > 20)) {
    problems.add('$label: per_order must be 1 to 20');
  }
  if (kind == GoalKind.race) {
    final length = start != null && end != null ? end.difference(start) : null;
    return [...problems, ..._raceProblems(config, label, length)];
  }
  final milestones = config['milestones'];
  if (milestones is! List<dynamic> ||
      milestones.isEmpty ||
      milestones.length > 40) {
    return [...problems, '$label: needs at least one milestone (at most 40)'];
  }
  var last = 0;
  for (final m in milestones) {
    final points = m is Map<String, dynamic> ? m['points'] : null;
    if (points is! int || points <= last) {
      problems.add('$label: milestone points must keep rising from 1');
      break;
    }
    last = points;
    if (!_rewardIsSound(m)) {
      problems.add('$label: milestone at $points gives nothing or too much');
    }
  }
  return problems;
}

/// A race: orders to deliver, four townsfolk with their hours, and three
/// prizes. [length] is how long the event runs.
List<String> _raceProblems(
  Map<String, dynamic> config,
  String label,
  Duration? length,
) {
  final problems = <String>[];
  final goal = config['goal'];
  if (goal is! int || goal < 1 || goal > 500) {
    problems.add('$label: goal must be 1 to 500 orders');
  }
  final rivals = config['rivals'];
  if (rivals is! List<dynamic> || rivals.length != 4) {
    problems.add('$label: a race needs exactly 4 rivals');
  } else {
    for (final rival in rivals) {
      if (rival case {
        'name': final String name,
        'hours': final int hours,
      } when name.trim().isNotEmpty && name.length <= 30 && hours >= 1) {
        if (length != null && hours > length.inHours) {
          problems.add('$label: "$name" takes longer than the race lasts');
        }
      } else {
        problems.add('$label: a rival needs a name (to 30 letters) and hours');
      }
    }
  }
  final prizes = config['prizes'];
  if (prizes is! List<dynamic> ||
      prizes.length != 3 ||
      !prizes.every(_rewardIsSound)) {
    problems.add('$label: a race needs 3 prizes, none empty or too large');
  }
  return problems;
}

bool _rewardIsSound(Object? reward) {
  if (reward is! Map<String, dynamic>) return false;
  var gives = false;
  for (final entry in _most.entries) {
    final amount = reward[entry.key] ?? 0;
    if (amount is! int || amount < 0 || amount > entry.value) return false;
    gives = gives || amount > 0;
  }
  final items = reward['items'] ?? const <dynamic>[];
  if (items is! List<dynamic> || items.length > 3) return false;
  if (items.any((id) => id is! String || id.isEmpty)) return false;
  return gives || items.isNotEmpty;
}

/// The goal events among [rows] that can be played, each id once. Rows that
/// are not goal events are passed over; a goal event with a mistake in it
/// is left out and named in [problems].
List<GoalEvent> playableGoalEvents(
  List<Object?> rows, {
  void Function(String problem)? problems,
}) {
  final seen = <String>{};
  final events = <GoalEvent>[];
  for (final row in rows) {
    if (!isGoalEventRow(row)) continue;
    final found = goalEventProblems(row);
    if (found.isNotEmpty) {
      problems?.call(found.join('; '));
      continue;
    }
    try {
      final event = GoalEvent.fromJson(row as Map<String, dynamic>);
      if (seen.add(event.id)) events.add(event);
    } on Object catch (e) {
      problems?.call('could not be read: $e');
    }
  }
  return events;
}
