// Naming rules for art files. Pure Dart so tool/process_assets.dart can use it.

final _itemName = RegExp(r'^item_[a-z]+_\d{2}$');

/// Turns a raw art file name into its clean item name, or null if it does not
/// follow `item_<chain>_<two-digit tier>`. Extra endings such as ".png.jpeg"
/// or "..jpeg" are ignored.
String? itemAssetBaseName(String fileName) {
  final dot = fileName.indexOf('.');
  final base = (dot < 0 ? fileName : fileName.substring(0, dot)).toLowerCase();
  return _itemName.hasMatch(base) ? base : null;
}

/// The art file name an item is expected to have, e.g. bakery_04 in chain
/// bakery -> item_bakery_04.
String expectedItemAssetBaseName(String chainId, int tier) =>
    'item_${chainId}_${tier.toString().padLeft(2, '0')}';

/// Item ids in [chainsJson] that have no art among [availableBaseNames].
List<String> itemsMissingArt(
  List<dynamic> chainsJson,
  Set<String> availableBaseNames,
) {
  final missing = <String>[];
  for (final c in chainsJson) {
    final chain = c as Map<String, dynamic>;
    for (final t in chain['tiers'] as List<dynamic>) {
      final tier = t as Map<String, dynamic>;
      final expected = expectedItemAssetBaseName(
        chain['id'] as String,
        tier['tier'] as int,
      );
      if (!availableBaseNames.contains(expected)) {
        missing.add(tier['item_id'] as String);
      }
    }
  }
  return missing;
}

// A character id may end in a digit (dockworker2).
final _characterName = RegExp(r'^char_([a-z]+[0-9]*)_([a-z]+)$');

/// Common misspellings in raw art names -> the spelling the game uses.
const _expressionFixes = {
  'suprised': 'surprised',
  'mad': 'angry',
  'nuetral': 'neutral',
};
const _characterFixes = {'naiomi': 'naomi'};

/// The six expressions every character portrait set may contain.
const portraitExpressions = {
  'neutral',
  'happy',
  'sad',
  'angry',
  'surprised',
  'thinking',
};

/// Turns a raw portrait file name into `char_<id>_<expression>`, fixing known
/// misspellings and ignoring extra endings. Returns null if the name does not
/// follow the pattern or the expression is not one the game knows.
String? characterAssetBaseName(String fileName) {
  final dot = fileName.indexOf('.');
  final base = (dot < 0 ? fileName : fileName.substring(0, dot)).toLowerCase();
  final match = _characterName.firstMatch(base);
  if (match == null) return null;
  final rawId = match.group(1) ?? '';
  final rawExpression = match.group(2) ?? '';
  final id = _characterFixes[rawId] ?? rawId;
  final expression = _expressionFixes[rawExpression] ?? rawExpression;
  if (!portraitExpressions.contains(expression)) return null;
  return 'char_${id}_$expression';
}

/// The portrait file for a character's expression, e.g. char_naomi_happy.
String portraitBaseName(String characterId, String expression) =>
    'char_${characterId}_$expression';

final _locationName = RegExp(r'^(loc_[a-z]+_[a-z]+_(?:before|after))');

/// The name the game uses for a raw location or background picture.
///
/// [names] maps the start of a raw file name to the game's name for it (from
/// tool/art_names.json): the longest matching start wins. Without a match, a
/// file that already begins `loc_<place>_<area>_<before|after>` keeps that
/// much of its name (dates and copy numbers after it are dropped). Returns
/// null when neither applies.
String? locationAssetBaseName(String fileName, Map<String, String> names) {
  final dot = fileName.lastIndexOf('.');
  final stem = dot <= 0 ? fileName : fileName.substring(0, dot);
  String? best;
  for (final start in names.keys) {
    if (stem.startsWith(start) &&
        (best == null || start.length > best.length)) {
      best = start;
    }
  }
  if (best != null) return names[best];
  return _locationName.firstMatch(stem.toLowerCase())?.group(1);
}

final _generatorName = RegExp(r'^(gen_[a-z]+)_l([1-9])$');

/// Turns a raw generator picture's file name into `<generator id>_l<level>`
/// (for example gen_pantry_l2). [otherNames] maps a name an artist may have
/// used to the generator's real id (gen_desk -> gen_scribe). Returns null if
/// the name does not follow `gen_<name>_l<level>`.
String? generatorAssetBaseName(
  String fileName, [
  Map<String, String> otherNames = const {},
]) {
  final dot = fileName.indexOf('.');
  final base = (dot < 0 ? fileName : fileName.substring(0, dot)).toLowerCase();
  final match = _generatorName.firstMatch(base);
  if (match == null) return null;
  final raw = match.group(1) ?? '';
  return '${otherNames[raw] ?? raw}_l${match.group(2)}';
}

/// Where the picture for a generator at [level] is kept.
String generatorArtPath(String generatorId, int level) =>
    'assets/generators/${generatorId}_l$level.jpg';
