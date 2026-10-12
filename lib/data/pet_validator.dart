// Checks content/pet.json. Pure Dart.

/// Words the pet must carry.
const petTextKeys = [
  'button',
  'title',
  'intro',
  'meter',
  'feed',
  'nothing',
  'gift',
  'new_look',
  'looks',
  'look_locked',
  'close',
];

const _most = {'pearls': 0, 'manna': 15, 'talents': 60};
final _id = RegExp(r'^[a-z0-9_]{1,40}$');
final _color = RegExp(r'^[0-9a-fA-F]{6}$');

/// Plain-English problems with the pet; empty if it is sound. [itemIds]
/// are the items the game has.
/// [itemManna] says how much Manna using an item gives: no gift may give
/// as much Manna as the food to earn it costs.
List<String> petProblems(
  Object? json, {
  required Set<String> itemIds,
  Map<String, int> itemManna = const {},
}) {
  if (json is! Map<String, dynamic>) {
    return ['Pet: the file is missing or has the wrong shape'];
  }
  final problems = <String>[];
  final goal = json['feed_goal'];
  if (goal is! int || goal < 5 || goal > 1000) {
    problems.add('Pet: feed_goal must be 5 to 1000');
  }
  final gifts = json['gifts'];
  if (gifts is! List<dynamic> || gifts.isEmpty || gifts.length > 20) {
    problems.add('Pet: it needs 1 to 20 gifts');
  } else {
    for (final (i, gift) in gifts.indexed) {
      final label = 'Pet gift ${i + 1}';
      var gives = false;
      for (final entry in _most.entries) {
        final amount = gift is Map<String, dynamic> ? gift[entry.key] ?? 0 : 0;
        if (amount is! int || amount < 0 || amount > entry.value) {
          problems.add('$label: at most ${entry.value} ${entry.key}');
        } else if (amount > 0) {
          gives = true;
        }
      }
      final items = gift is Map<String, dynamic>
          ? gift['items'] ?? const <dynamic>[]
          : const <dynamic>[];
      if (items is! List<dynamic> || items.length > 1) {
        problems.add('$label: at most 1 item');
      } else {
        for (final item in items) {
          if (!itemIds.contains(item)) problems.add('$label: no item "$item"');
        }
        gives = gives || items.isNotEmpty;
      }
      if (!gives) problems.add('$label: it gives nothing');
      var manna = switch (gift) {
        {'manna': final int n} => n,
        _ => 0,
      };
      if (items is List<dynamic>) {
        for (final item in items) {
          manna += itemManna[item] ?? 0;
        }
      }
      if (goal is int && manna >= goal) {
        problems.add('$label: it gives as much Manna as the food costs');
      }
    }
  }
  final looks = json['looks'];
  if (looks is! List<dynamic> || looks.isEmpty || looks.length > 12) {
    problems.add('Pet: it needs 1 to 12 looks');
  } else {
    final seen = <String>{};
    for (final (i, look) in looks.indexed) {
      if (look
          case {
            'id': final String id,
            'name': final String name,
            'gifts': final int count,
            'color': final String color,
          }
          when _id.hasMatch(id) &&
              name.trim().isNotEmpty &&
              name.length <= 30 &&
              count >= 0 &&
              _color.hasMatch(color)) {
        if (!seen.add(id)) problems.add('Pet: look "$id" is listed twice');
        if (i == 0 && count != 0) {
          problems.add('Pet: the first look must need 0 gifts');
        }
      } else {
        problems.add(
          'Pet: a look needs an id, a name (to 30 letters), gifts and a '
          'six-letter color',
        );
      }
    }
  }
  final text = json['text'];
  for (final key in petTextKeys) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is! String || words.isEmpty || words.length > 120) {
      problems.add('Pet: text "$key" is missing or longer than 120 letters');
    }
  }
  for (final (key, places) in const [
    ('meter', ['{fed}', '{goal}']),
    ('gift', ['{reward}']),
    ('new_look', ['{name}']),
    ('look_locked', ['{gifts}']),
  ]) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is String && !places.every(words.contains)) {
      problems.add('Pet: text "$key" must contain ${places.join(' and ')}');
    }
  }
  return problems;
}
