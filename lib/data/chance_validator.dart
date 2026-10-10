// Checks content/chance.json (the Blessing Wheel and other chance rewards).
// Pure Dart.

/// Words every chance.json must carry.
const chanceTextKeys = [
  'wheel_title',
  'wheel_button',
  'spin_free',
  'spin_ad',
  'spin_pearls',
  'spins_done',
  'see_odds',
  'odds_title',
  'odds_free',
  'odds_paid',
  'odds_note',
  'won_title',
  'won_button',
  'close',
];

/// Plain-English problems with the chance file; empty if it is sound.
/// [chainsJson] and [generatorsJson] are the already-checked content the
/// prizes refer to.
List<String> chanceProblems(
  Object? json, {
  required Object? chainsJson,
  required Object? generatorsJson,
}) {
  final problems = <String>[];
  try {
    if (json is! Map<String, dynamic>) {
      return ['Chance: the file is missing or has the wrong shape'];
    }
    final itemIds = {
      for (final chain in chainsJson as List<dynamic>)
        for (final tier
            in (chain as Map<String, dynamic>)['tiers'] as List<dynamic>)
          (tier as Map<String, dynamic>)['item_id'],
    };
    final temporary = {
      for (final g in generatorsJson as List<dynamic>)
        if ((g as Map<String, dynamic>)['type'] == 'temporary') g['id'],
    };
    final blocked = json['paid_blocked_countries'];
    if (blocked is! List<dynamic> ||
        blocked.any((c) => c is! String || !_country.hasMatch(c))) {
      problems.add(
        'Chance: paid_blocked_countries must be a list of two-letter '
        'country codes in capitals',
      );
    }
    final wheel = json['wheel'] as Map<String, dynamic>;
    for (final key in [
      'free_spins_per_day',
      'ad_spins_per_day',
      'pearl_spins_per_day',
      'pearl_spin_step',
    ]) {
      final value = wheel[key];
      if (value is! int || value < 0) {
        problems.add('Wheel: $key must be a whole number, 0 or more');
      }
    }
    final base = wheel['pearl_spin_base'];
    if (base is! int || base < 1) {
      problems.add('Wheel: pearl_spin_base must be 1 or more');
    }
    checkPrizes(
      'Wheel',
      wheel['prizes'],
      itemIds: itemIds,
      temporaryGeneratorIds: temporary,
      problems: problems,
    );
    final text = json['text'];
    for (final key in chanceTextKeys) {
      final words = text is Map<String, dynamic> ? text[key] : null;
      if (words is! String || words.isEmpty || words.length > 200) {
        problems.add(
          'Chance: text "$key" is missing or longer than 200 letters',
        );
      }
    }
  } on TypeError catch (e) {
    problems.add(
      'Chance: a field is missing or is the wrong kind of value '
      '(details: $e)',
    );
  }
  return problems;
}

final _country = RegExp(r'^[A-Z]{2}$');
final _id = RegExp(r'^[a-z][a-z0-9_]*$');

/// Adds a line to [problems] for anything wrong with a list of prizes
/// ([what] names whose they are).
void checkPrizes(
  String what,
  Object? prizes, {
  required Set<Object?> itemIds,
  required Set<Object?> temporaryGeneratorIds,
  required List<String> problems,
}) {
  if (prizes is! List<dynamic> || prizes.isEmpty) {
    problems.add('$what: has no prizes');
    return;
  }
  final seen = <String>{};
  var paidWeight = 0;
  for (final entry in prizes) {
    final prize = entry as Map<String, dynamic>;
    final id = prize['id'];
    if (id is! String || !_id.hasMatch(id) || !seen.add(id)) {
      problems.add('$what: prize id "$id" is missing, odd or used twice');
    }
    final name = prize['name'];
    if (name is! String || name.trim().isEmpty || name.length > 30) {
      problems.add('$what prize $id: needs a name of 1 to 30 letters');
    }
    final weight = prize['weight'];
    if (weight is! int || weight < 1) {
      problems.add('$what prize $id: weight must be 1 or more');
    }
    var gives = 0;
    for (final key in ['manna', 'talents', 'pearls']) {
      final amount = prize[key];
      if (amount != null && (amount is! int || amount < 1)) {
        problems.add('$what prize $id: $key must be 1 or more');
      }
      if (amount is int) gives += amount;
    }
    for (final item in prize['items'] as List<dynamic>? ?? const []) {
      gives++;
      if (!itemIds.contains(item)) {
        problems.add('$what prize $id: unknown item "$item"');
      }
    }
    for (final gen in prize['generators'] as List<dynamic>? ?? const []) {
      gives++;
      if (!temporaryGeneratorIds.contains(gen)) {
        problems.add('$what prize $id: "$gen" is not a temporary generator');
      }
    }
    if (gives == 0) problems.add('$what prize $id: gives nothing');
    final freeOnly = prize['free_only'];
    if (freeOnly != null && freeOnly is! bool) {
      problems.add('$what prize $id: free_only must be true or false');
    }
    // Pearls are never the prize of a try paid for with Pearls.
    if (prize['pearls'] != null && freeOnly != true) {
      problems.add(
        '$what prize $id: a prize of Pearls must be marked free_only',
      );
    }
    if (freeOnly != true && weight is int) paidWeight += weight;
  }
  if (paidWeight == 0) {
    problems.add('$what: no prize is left for a paid try');
  }
}
