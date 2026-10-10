// Checks content/levels.json. Pure Dart.

const _textKeys = [
  'title',
  'manna',
  'talents',
  'gift',
  'unlocked',
  'continue',
  'badge',
];

/// Adds a plain-English line to [problems] for every mistake.
void checkLevels(
  Map<String, dynamic> json, {
  required Set<int> chapterNumbers,
  required List<String> problems,

  /// Ids a level may give; null skips that check.
  Set<String>? itemIds,
  Set<String>? generatorIds,
}) {
  final perChapter = json['xp_per_task_by_chapter'];
  if (perChapter is! Map<String, dynamic>) {
    problems.add('Levels: xp_per_task_by_chapter is missing');
  } else {
    for (final e in perChapter.entries) {
      final chapter = int.tryParse(e.key);
      if (chapter == null || !chapterNumbers.contains(chapter)) {
        problems.add(
          'Levels: XP is set for chapter "${e.key}", which does not exist',
        );
      }
      final xp = e.value;
      if (xp is! int || xp < 1) {
        problems.add(
          'Levels: XP per task for chapter ${e.key} must be 1 or more',
        );
      }
    }
  }
  final fallback = json['xp_per_task_default'];
  if (fallback is! int || fallback < 1) {
    problems.add('Levels: xp_per_task_default must be 1 or more');
  }

  final levels = json['levels'];
  var top = 1;
  if (levels is! List<dynamic> || levels.isEmpty) {
    problems.add('Levels: the list of levels is missing or empty');
  } else {
    var lastXp = 0;
    var expected = 2;
    for (final entry in levels) {
      if (entry is! Map<String, dynamic>) {
        problems.add('Levels: a level is not written as a record');
        continue;
      }
      final level = entry['level'];
      final xp = entry['xp'];
      final talents = entry['talents'] ?? 0;
      if (level != expected) {
        problems.add('Levels: expected level $expected next, found "$level"');
      }
      if (xp is! int || xp <= lastXp) {
        problems.add(
          'Levels: level $level must need more XP than the level before',
        );
      } else {
        lastXp = xp;
      }
      if (talents is! int || talents < 0) {
        problems.add('Levels: level $level has a bad Talents reward');
      }
      final items = entry['items'] ?? const <dynamic>[];
      if (items is! List<dynamic>) {
        problems.add('Levels: level $level items must be a list');
      } else if (itemIds != null) {
        for (final item in items) {
          if (!itemIds.contains(item)) {
            problems.add('Levels: level $level gives unknown item "$item"');
          }
        }
      }
      final generator = entry['generator'];
      if (generator != null &&
          generatorIds != null &&
          !generatorIds.contains(generator)) {
        problems.add(
          'Levels: level $level gives unknown generator "$generator"',
        );
      }
      expected++;
    }
    top = expected - 1;
  }

  final unlocks = json['unlocks'] ?? const <dynamic>[];
  if (unlocks is! List<dynamic>) {
    problems.add('Levels: unlocks must be a list');
  } else {
    final seen = <String>{};
    for (final entry in unlocks) {
      if (entry is! Map<String, dynamic>) {
        problems.add('Levels: an unlock is not written as a record');
        continue;
      }
      final feature = entry['feature'];
      final level = entry['level'];
      final name = entry['name'];
      if (feature is! String || feature.isEmpty || !seen.add(feature)) {
        problems.add('Levels: unlock "$feature" is missing or listed twice');
      }
      if (level is! int || level < 2 || level > top) {
        problems.add('Levels: unlock "$feature" needs a level from 2 to $top');
      }
      if (name is! String || name.isEmpty || name.length > 40) {
        problems.add(
          'Levels: unlock "$feature" needs a name of 1 to 40 letters',
        );
      }
      if (entry['available'] is! bool?) {
        problems.add(
          'Levels: unlock "$feature": available must be true or false',
        );
      }
    }
  }

  final text = json['text'];
  for (final key in _textKeys) {
    final value = text is Map<String, dynamic> ? text[key] : null;
    if (value is! String || value.isEmpty || value.length > 60) {
      problems.add('Levels: text "$key" is missing or longer than 60 letters');
    }
  }
}
