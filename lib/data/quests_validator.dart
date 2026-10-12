// Checks content/quests.json. Pure Dart.

/// Words the order quests must carry.
const questsTextKeys = [
  'button',
  'title',
  'intro',
  'need',
  'give',
  'reward',
  'finished',
  'locked',
  'close',
];

const _most = {'pearls': 30, 'manna': 200, 'talents': 1500};
final _id = RegExp(r'^[a-z0-9_]{1,40}$');

/// Plain-English problems with the order quests; empty if they are sound.
List<String> questsProblems(
  Object? json, {
  required Set<String> itemIds,
  required Set<String> chapterIds,
}) {
  if (json is! Map<String, dynamic>) {
    return ['Order quests: the file is missing or has the wrong shape'];
  }
  final problems = <String>[];
  final quests = json['quests'];
  if (quests is! List<dynamic>) {
    problems.add('Order quests: "quests" must be a list');
  } else {
    final seen = <String>{};
    for (final quest in quests) {
      if (quest case {
        'id': final String id,
        'chapter': final String chapter,
        'name': final String name,
        'text': final String text,
        'done': final String done,
        'needs': final Map<String, dynamic> needs,
      }) {
        final label = 'Order quest "$id"';
        if (!_id.hasMatch(id) || !seen.add(id)) {
          problems.add('$label: the id is wrong or used twice');
        }
        if (!chapterIds.contains(chapter)) {
          problems.add('$label: there is no chapter "$chapter"');
        }
        if (name.trim().isEmpty || name.length > 32) {
          problems.add('$label: name must be 1 to 32 letters');
        }
        if (text.trim().isEmpty || text.length > 150) {
          problems.add('$label: text must be 1 to 150 letters');
        }
        if (done.trim().isEmpty || done.length > 120) {
          problems.add('$label: done must be 1 to 120 letters');
        }
        if (needs.isEmpty || needs.length > 6) {
          problems.add('$label: it needs 1 to 6 kinds of item');
        }
        for (final e in needs.entries) {
          final count = e.value;
          if (!itemIds.contains(e.key)) {
            problems.add('$label: no item "${e.key}"');
          } else if (count is! int || count < 1 || count > 9) {
            problems.add('$label: 1 to 9 of "${e.key}"');
          }
        }
        final reward = quest['reward'];
        var gives = false;
        for (final entry in _most.entries) {
          final amount = reward is Map<String, dynamic>
              ? reward[entry.key] ?? 0
              : 0;
          if (amount is! int || amount < 0 || amount > entry.value) {
            problems.add('$label: a wrong amount of ${entry.key}');
          } else if (amount > 0) {
            gives = true;
          }
        }
        final items = reward is Map<String, dynamic>
            ? reward['items'] ?? const <dynamic>[]
            : const <dynamic>[];
        if (items is! List<dynamic> || items.length > 3) {
          problems.add('$label: at most 3 reward items');
        } else {
          for (final item in items) {
            if (!itemIds.contains(item)) {
              problems.add('$label: no reward item "$item"');
            }
          }
          gives = gives || items.isNotEmpty;
        }
        if (!gives) problems.add('$label: its reward gives nothing');
      } else {
        problems.add(
          'Order quests: a quest needs id, chapter, name, text, done and needs',
        );
      }
    }
  }
  final text = json['text'];
  for (final key in questsTextKeys) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is! String || words.isEmpty || words.length > 120) {
      problems.add(
        'Order quests: text "$key" is missing or longer than 120 letters',
      );
    }
  }
  for (final (key, places) in const [
    ('need', ['{name}', '{have}', '{all}']),
    ('reward', ['{reward}']),
    ('finished', ['{reward}']),
  ]) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is String && !places.every(words.contains)) {
      problems.add(
        'Order quests: text "$key" must contain ${places.join(' and ')}',
      );
    }
  }
  return problems;
}
