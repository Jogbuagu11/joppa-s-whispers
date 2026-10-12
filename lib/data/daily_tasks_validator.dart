// Checks content/daily_tasks.json. Pure Dart.
import 'package:whispers_of_joppa/domain/daily_tasks.dart';

/// Words the daily tasks must carry, and the places each must have.
const dailyTasksTextKeys = {
  'button': <String>[],
  'title': <String>[],
  'new_in': ['{time}'],
  'progress': ['{done}', '{target}'],
  'reward': ['{reward}'],
  'done': <String>[],
  'chest': ['{n}', '{reward}'],
  'chest_done': <String>[],
  'weekly': ['{done}', '{days}', '{reward}'],
  'weekly_done': <String>[],
  'toast_task': ['{reward}'],
  'toast_chest': ['{reward}'],
  'toast_weekly': ['{reward}'],
  'close': <String>[],
};

// No single reward gives more than this, whatever a slip of the finger says.
const _most = {'pearls': 50, 'manna': 200, 'talents': 1000};

/// Plain-English problems with the daily tasks; empty if they are sound.
/// [itemIds] are the items the game has.
List<String> dailyTasksProblems(Object? json, {required Set<String> itemIds}) {
  if (json is! Map<String, dynamic>) {
    return ['Daily tasks: the file is missing or has the wrong shape'];
  }
  final problems = <String>[];
  String? rewardProblem(Object? reward) {
    if (reward is! Map<String, dynamic>) return 'has no reward';
    var gives = false;
    for (final entry in _most.entries) {
      final amount = reward[entry.key] ?? 0;
      if (amount is! int || amount < 0 || amount > entry.value) {
        return 'gives a wrong amount of ${entry.key}';
      }
      gives = gives || amount > 0;
    }
    final items = reward['items'] ?? const <dynamic>[];
    if (items is! List<dynamic> || items.length > 3) {
      return 'gives more than 3 items';
    }
    for (final id in items) {
      if (!itemIds.contains(id)) return 'gives an unknown item "$id"';
    }
    return gives || items.isNotEmpty ? null : 'gives nothing';
  }

  final perDay = json['per_day'];
  final pool = json['pool'];
  if (perDay is! int || perDay < 1 || perDay > 8) {
    problems.add('Daily tasks: per_day must be 1 to 8');
  }
  if (pool is! List<dynamic> || pool.isEmpty) {
    problems.add('Daily tasks: the pool is empty');
  } else {
    if (perDay is int && pool.length < perDay) {
      problems.add('Daily tasks: the pool has fewer tasks than a day needs');
    }
    final seen = <String>{};
    for (final task in pool) {
      if (task case {
        'id': final String id,
        'kind': final String kind,
        'target': final int target,
        'text': final String text,
      }) {
        final label = 'Daily task "$id"';
        if (!seen.add(id)) problems.add('$label: listed twice');
        if (!dailyKindNames.containsKey(kind)) {
          problems.add('$label: unknown kind "$kind"');
        }
        if (target < 1 || target > 100000) {
          problems.add('$label: target must be 1 or more');
        }
        if (text.trim().isEmpty || text.length > 60) {
          problems.add('$label: text must be 1 to 60 letters');
        }
        final wrong = rewardProblem(task['reward']);
        if (wrong != null) problems.add('$label: $wrong');
      } else {
        problems.add('Daily tasks: a task needs an id, kind, target and text');
      }
    }
  }
  final chest = rewardProblem(json['chest']);
  if (chest != null) problems.add('Daily tasks: the chest $chest');
  final weekly = json['weekly'];
  final days = weekly is Map<String, dynamic> ? weekly['days'] : null;
  if (days is! int || days < 1 || days > 7) {
    problems.add('Daily tasks: weekly days must be 1 to 7');
  }
  final weeklyReward = rewardProblem(
    weekly is Map<String, dynamic> ? weekly['reward'] : null,
  );
  if (weeklyReward != null) {
    problems.add('Daily tasks: the weekly chest $weeklyReward');
  }
  final text = json['text'];
  for (final entry in dailyTasksTextKeys.entries) {
    final words = text is Map<String, dynamic> ? text[entry.key] : null;
    if (words is! String || words.isEmpty || words.length > 120) {
      problems.add(
        'Daily tasks: text "${entry.key}" is missing or longer than 120 '
        'letters',
      );
    } else if (!entry.value.every(words.contains)) {
      problems.add(
        'Daily tasks: text "${entry.key}" must contain '
        '${entry.value.join(' and ')}',
      );
    }
  }
  return problems;
}
