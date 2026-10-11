// Checks content/offers.json (the shop's daily deals). Pure Dart.
import 'package:whispers_of_joppa/domain/deals.dart';

/// Words every offers.json must carry.
const offersTextKeys = [
  'deals_title',
  'deal_free',
  'deal_price',
  'deal_taken',
  'deals_note',
  'shop_unavailable',
  'shop_owned',
];

/// Plain-English problems with the offers file; empty if it is sound.
List<String> offersProblems(
  Object? json, {
  required Object? chainsJson,
  Object? productsJson,
}) {
  final problems = <String>[];
  try {
    if (json is! Map<String, dynamic>) {
      return ['Offers: the file is missing or has the wrong shape'];
    }
    checkDeals(
      json['daily_deals'],
      itemIds: {
        for (final chain in chainsJson as List<dynamic>)
          for (final tier
              in (chain as Map<String, dynamic>)['tiers'] as List<dynamic>)
            (tier as Map<String, dynamic>)['item_id'],
      },
      problems: problems,
    );
    _checkSpecial(json['special'], productsJson, problems);
    final text = json['text'];
    for (final key in offersTextKeys) {
      final words = text is Map<String, dynamic> ? text[key] : null;
      if (words is! String || words.isEmpty || words.length > 120) {
        problems.add(
          'Offers: text "$key" is missing or longer than 120 letters',
        );
      }
    }
  } on TypeError catch (e) {
    problems.add(
      'Offers: a field is missing or is the wrong kind of value '
      '(details: $e)',
    );
  }
  return problems;
}

/// The Joppa Special: its words, and packs that are real Pearl products.
void _checkSpecial(
  Object? special,
  Object? productsJson,
  List<String> problems,
) {
  if (special == null) return;
  if (special is! Map<String, dynamic>) {
    problems.add('Special: must be a record');
    return;
  }
  for (final key in [
    'title',
    'subtitle',
    'picture',
    'no_thanks',
    'unavailable',
    'pearls_word',
    'button',
  ]) {
    final words = special[key];
    if (words is! String || words.isEmpty || words.length > 80) {
      problems.add('Special: "$key" is missing or longer than 80 letters');
    }
  }
  final packs = special['packs'];
  if (packs is! List<dynamic> || packs.isEmpty || packs.length > 3) {
    problems.add('Special: needs one to three packs');
    return;
  }
  // product_id -> the Pearls it gives.
  final pearls = {
    if (productsJson is List<dynamic>)
      for (final p in productsJson)
        (p as Map<String, dynamic>)['id']: p['pearls'],
  };
  final seen = <Object?>{};
  for (final entry in packs) {
    final pack = entry as Map<String, dynamic>;
    final id = pack['product_id'];
    if (!seen.add(id)) problems.add('Special: pack "$id" is listed twice');
    final gives = pearls[id];
    if (productsJson != null && (gives is! int || gives < 1)) {
      problems.add('Special: pack "$id" is not a product that gives Pearls');
    }
    final name = pack['name'];
    if (name is! String || name.trim().isEmpty || name.length > 24) {
      problems.add('Special: pack "$id" needs a name of 1 to 24 letters');
    }
    if (pack['featured'] is! bool?) {
      problems.add('Special: pack "$id": featured must be true or false');
    }
  }
}
