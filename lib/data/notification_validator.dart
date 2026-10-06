// Checks content/notifications.json. Pure Dart.

const _textLimits = {
  'explainer': {'title': 40, 'body': 220, 'yes': 24, 'no': 24},
  'manna_full': {'title': 40, 'body': 110},
  'come_back': {'title': 40, 'body': 110},
  'settings': {
    'title': 30,
    'reminders': 40,
    'reminders_hint': 90,
    'events': 40,
    'events_hint': 90,
    'chapters': 40,
    'chapters_hint': 90,
    'blocked': 160,
  },
};

/// Adds a plain-English line to [problems] for every mistake.
void checkNotifications(
  Map<String, dynamic> json, {
  required Set<String> taskIds,
  required List<String> problems,
}) {
  final task = json['ask_after_task'];
  if (task is! String || !taskIds.contains(task)) {
    problems.add('Notifications: ask_after_task "$task" is not a story task');
  }
  for (final key in ['quiet_start_hour', 'quiet_end_hour']) {
    final hour = json[key];
    if (hour is! int || hour < 0 || hour > 23) {
      problems.add('Notifications: $key must be an hour from 0 to 23');
    }
  }
  _textLimits.forEach((section, limits) {
    final part = json[section];
    if (part is! Map<String, dynamic>) {
      problems.add('Notifications: "$section" is missing');
      return;
    }
    limits.forEach((key, limit) {
      final text = part[key];
      if (text is! String || text.trim().isEmpty) {
        problems.add('Notifications: $section.$key is missing');
      } else if (text.length > limit) {
        problems.add(
          'Notifications: $section.$key is ${text.length} characters '
          '(limit $limit)',
        );
      }
    });
  });
  final manna = json['manna_full'];
  if (manna is Map<String, dynamic>) {
    final low = manna['low_percent'];
    if (low is! int || low < 1 || low > 100) {
      problems.add('Notifications: manna_full.low_percent must be 1 to 100');
    }
  }
  final back = json['come_back'];
  if (back is Map<String, dynamic>) {
    final days = back['after_days'];
    if (days is! int || days < 1) {
      problems.add('Notifications: come_back.after_days must be 1 or more');
    }
    final repeat = back['repeat_days'];
    if (repeat is! int || repeat < 1) {
      problems.add('Notifications: come_back.repeat_days must be 1 or more');
    }
  }
}
