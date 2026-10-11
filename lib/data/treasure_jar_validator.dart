// Checks the Treasure Jar's part of content/offers.json. Pure Dart.

/// Words the Treasure Jar must carry.
const treasureJarTextKeys = [
  'button',
  'title',
  'filling',
  'full',
  'count',
  'open',
  'not_full',
  'next',
  'close',
  'sign_in',
  'unavailable',
];

/// Plain-English problems with "treasure_jar" ([jar]) in the offers file
/// ([offersJson]); empty if it is sound, or if there is no jar at all
/// (older content: the game then has none).
List<String> treasureJarProblems(Object? jar, Map<String, dynamic> offersJson) {
  if (jar == null) return const [];
  if (jar is! Map<String, dynamic>) {
    return ['Treasure Jar: it must be a group of settings'];
  }
  final problems = <String>[];
  final sizes = jar['sizes'];
  if (sizes is! List<dynamic> || sizes.isEmpty) {
    problems.add('Treasure Jar: it needs at least one size');
  } else {
    final offerProducts = offersJson['offer_products'];
    final seen = <Object?>{};
    var last = 0;
    for (final size in sizes) {
      if (size case {
        'id': final String id,
        'product_id': final String productId,
        'pearls': final int pearls,
      }) {
        if (!seen.add(id) || !seen.add(productId)) {
          problems.add('Treasure Jar: size "$id" is listed twice');
        }
        if (offerProducts is List<dynamic> &&
            offerProducts.contains(productId)) {
          problems.add('Treasure Jar: "$productId" is an offer product');
        }
        // Each jar holds more than the one before it.
        if (pearls <= last) {
          problems.add('Treasure Jar: size "$id" must hold more than the last');
        }
        last = pearls;
      } else {
        problems.add('Treasure Jar: a size needs an id, a product and Pearls');
      }
    }
  }
  final earn = jar['earn'];
  var earns = false;
  for (final key in const ['order', 'task', 'level']) {
    final amount = earn is Map<String, dynamic> ? earn[key] : null;
    if (amount is! int? || (amount ?? 0) < 0) {
      problems.add(
        'Treasure Jar: earn "$key" must be a whole number, 0 or more',
      );
    } else if ((amount ?? 0) > 0) {
      earns = true;
    }
  }
  if (!earns) problems.add('Treasure Jar: nothing fills it (see "earn")');
  final text = jar['text'];
  for (final key in treasureJarTextKeys) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is! String || words.isEmpty || words.length > 120) {
      problems.add(
        'Treasure Jar: text "$key" is missing or longer than 120 letters',
      );
    }
  }
  // The words that carry a number must have a place for it.
  for (final (key, places) in const [
    ('count', ['{saved}', '{pearls}']),
    ('open', ['{price}']),
  ]) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is String && !places.every(words.contains)) {
      problems.add(
        'Treasure Jar: text "$key" must contain ${places.join(' and ')}',
      );
    }
  }
  return problems;
}
