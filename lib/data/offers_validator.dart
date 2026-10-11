// Checks content/offers.json (the shop's daily deals). Pure Dart.
import 'package:whispers_of_joppa/data/season_pass_validator.dart';
import 'package:whispers_of_joppa/data/treasure_jar_validator.dart';
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
  'first_purchase',
  'offer_subtitle',
  'offer_ends_in',
  'offer_no_thanks',
  'offer_close',
  'offer_pearls',
  'offer_manna',
  'offer_talents',
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
    _checkOfferSetup(json, productsJson, problems);
    problems.addAll(treasureJarProblems(json['treasure_jar'], json));
    problems.addAll(seasonPassProblems(json));
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

/// The reusable offer products (store products that carry only a price)
/// and how often offers may appear.
void _checkOfferSetup(
  Map<String, dynamic> json,
  Object? productsJson,
  List<String> problems,
) {
  final ids = json['offer_products'];
  if (ids is! List<dynamic> || ids.isEmpty || ids.any((id) => id is! String)) {
    problems.add('Offers: offer_products must be a list of product ids');
  } else {
    final shop = {
      if (productsJson is List<dynamic>)
        for (final p in productsJson)
          if (p case {'id': final String id}) id,
    };
    for (final id in ids) {
      if (shop.contains(id)) {
        problems.add('Offers: "$id" is a shop product, not an offer product');
      }
    }
    if (ids.toSet().length != ids.length) {
      problems.add('Offers: offer_products lists a product twice');
    }
  }
  final rules = json['rules'];
  for (final key in const [
    'max_per_session',
    'max_at_session_start',
    'session_start_per_day',
    'level_every',
  ]) {
    final value = rules is Map<String, dynamic> ? rules[key] : null;
    if (value is! int || value < 0 || value > 20) {
      problems.add('Offers: rules.$key must be a whole number from 0 to 20');
    }
  }
  final repeat = rules is Map<String, dynamic>
      ? rules['repeat_after_hours']
      : null;
  if (repeat is! int || repeat < 0 || repeat > 24 * 60) {
    problems.add('Offers: rules.repeat_after_hours must be 0 (never) to 1440');
  }
}
