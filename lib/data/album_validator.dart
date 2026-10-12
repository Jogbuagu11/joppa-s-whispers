// Checks content/album.json. Pure Dart.

/// Words the album must carry.
const albumTextKeys = [
  'button',
  'title',
  'set',
  'prize',
  'unknown',
  'found',
  'spare',
  'finished',
  'close',
];

const _most = {'pearls': 50, 'manna': 300, 'talents': 2000};
final _id = RegExp(r'^[a-z0-9_]{1,40}$');

/// Plain-English problems with the album; empty if it is sound. [itemIds]
/// are the items the game has.
List<String> albumProblems(Object? json, {required Set<String> itemIds}) {
  if (json is! Map<String, dynamic>) {
    return ['Album: the file is missing or has the wrong shape'];
  }
  final problems = <String>[];
  final percent = json['order_percent'];
  if (percent is! int || percent < 1 || percent > 100) {
    problems.add('Album: order_percent must be 1 to 100');
  }
  final sets = json['sets'];
  if (sets is! List<dynamic> || sets.isEmpty) {
    problems.add('Album: it needs at least one set');
  } else {
    final seen = <String>{};
    for (final set in sets) {
      if (set case {
        'id': final String id,
        'name': final String name,
        'cards': final List<dynamic> cards,
      } when cards.isNotEmpty) {
        final label = 'Album set "$id"';
        if (!_id.hasMatch(id) || !seen.add('set $id')) {
          problems.add('$label: the id is wrong or used twice');
        }
        if (name.trim().isEmpty || name.length > 24) {
          problems.add('$label: name must be 1 to 24 letters');
        }
        for (final card in cards) {
          if (card
              case {
                'id': final String cardId,
                'name': final String cardName,
                'note': final String note,
              }
              when _id.hasMatch(cardId) &&
                  cardName.trim().isNotEmpty &&
                  cardName.length <= 22 &&
                  note.trim().isNotEmpty &&
                  note.length <= 110) {
            if (!seen.add(cardId)) {
              problems.add('$label: card "$cardId" is listed twice');
            }
          } else {
            problems.add(
              '$label: a card needs an id, a name (to 22 letters) and a note '
              '(to 110)',
            );
          }
        }
        final reward = set['reward'];
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
          problems.add('$label: at most 3 items');
        } else {
          for (final item in items) {
            if (!itemIds.contains(item)) {
              problems.add('$label: no item "$item"');
            }
          }
          gives = gives || items.isNotEmpty;
        }
        if (!gives) problems.add('$label: its prize gives nothing');
      } else {
        problems.add('Album: a set needs an id, a name and cards');
      }
    }
  }
  final text = json['text'];
  for (final key in albumTextKeys) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is! String || words.isEmpty || words.length > 80) {
      problems.add('Album: text "$key" is missing or longer than 80 letters');
    }
  }
  for (final (key, places) in const [
    ('set', ['{name}', '{found}', '{all}']),
    ('prize', ['{reward}']),
    ('found', ['{name}']),
    ('spare', ['{name}']),
    ('finished', ['{name}', '{reward}']),
  ]) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is String && !places.every(words.contains)) {
      problems.add('Album: text "$key" must contain ${places.join(' and ')}');
    }
  }
  return problems;
}
