// Checks content/calendar.json. Pure Dart.

/// Words the calendar must carry.
const calendarTextKeys = ['button', 'title', 'take', 'taken', 'day', 'close'];

// No single day gives more than this.
const _most = {'pearls': 30, 'manna': 200, 'talents': 1000};

/// Plain-English problems with the login calendar; empty if it is sound.
/// [itemIds] are the items the game has.
List<String> calendarProblems(Object? json, {required Set<String> itemIds}) {
  if (json is! Map<String, dynamic>) {
    return ['Calendar: the file is missing or has the wrong shape'];
  }
  final problems = <String>[];
  final days = json['days'];
  if (days is! List<dynamic> || days.length != 28) {
    problems.add('Calendar: it needs exactly 28 days');
  } else {
    final verses = <String>{};
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final label = 'Calendar day ${i + 1}';
      if (day is! Map<String, dynamic>) {
        problems.add('$label: it must be a group of settings');
        continue;
      }
      var gives = false;
      for (final entry in _most.entries) {
        final amount = day[entry.key] ?? 0;
        if (amount is! int || amount < 0 || amount > entry.value) {
          problems.add('$label: a wrong amount of ${entry.key}');
        } else if (amount > 0) {
          gives = true;
        }
      }
      final items = day['items'] ?? const <dynamic>[];
      if (items is! List<dynamic> || items.length > 3) {
        problems.add('$label: at most 3 items');
      } else {
        for (final id in items) {
          if (!itemIds.contains(id)) problems.add('$label: no item "$id"');
        }
        gives = gives || items.isNotEmpty;
      }
      if (!gives) problems.add('$label: it gives nothing');
      final verse = day['verse'];
      final ref = day['ref'];
      if (verse is! String || verse.trim().isEmpty || verse.length > 180) {
        problems.add('$label: the verse must be 1 to 180 letters');
      } else if (!verses.add(verse)) {
        problems.add('$label: the verse is used twice');
      }
      // Scripture is quoted only from the two public-domain translations.
      if (ref is! String ||
          !RegExp(r'^.+ \d+:\d+.* \((KJV|WEB)\)$').hasMatch(ref)) {
        problems.add('$label: the reference must end with (KJV) or (WEB)');
      }
    }
  }
  final text = json['text'];
  for (final key in calendarTextKeys) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is! String || words.isEmpty || words.length > 80) {
      problems.add(
        'Calendar: text "$key" is missing or longer than 80 letters',
      );
    }
  }
  final day = text is Map<String, dynamic> ? text['day'] : null;
  if (day is String && !day.contains('{n}')) {
    problems.add('Calendar: text "day" must contain {n}');
  }
  return problems;
}
