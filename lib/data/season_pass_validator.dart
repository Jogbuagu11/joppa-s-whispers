// Checks the season pass: an event's "pass" settings, and the pass's part
// of content/offers.json. Pure Dart.

/// Words the season pass must carry.
const seasonPassTextKeys = [
  'button',
  'title',
  'buy_premium',
  'buy_plus',
  'upgrade',
  'have_free',
  'have_premium',
  'have_plus',
  'premium_note',
  'plus_note',
  'endless',
  'this_event',
  'at_points',
  'pearls',
  'manna',
  'talents',
  'sign_in',
  'unavailable',
  'close',
];

// No single step gives more than this, whatever a slip of the finger says.
const _most = {'pearls': 200, 'manna': 500, 'talents': 5000};

bool _rewardIsSound(Object? reward, {required bool mayBeEmpty}) {
  if (reward is! Map<String, dynamic>) return false;
  var gives = false;
  for (final entry in _most.entries) {
    final amount = reward[entry.key] ?? 0;
    if (amount is! int || amount < 0 || amount > entry.value) return false;
    gives = gives || amount > 0;
  }
  final items = reward['items'] ?? const <dynamic>[];
  if (items is! List<dynamic> || items.length > 3) return false;
  if (items.any((id) => id is! String || id.isEmpty)) return false;
  return mayBeEmpty || gives || items.isNotEmpty;
}

/// Plain-English problems with an event's "pass" ([pass]); empty if it is
/// sound or the event has none. [milestones] is how many milestones the
/// event has; [label] names the event.
List<String> eventPassProblems(Object? pass, int milestones, String label) {
  if (pass == null) return const [];
  if (pass is! Map<String, dynamic>) return ['$label: pass must be settings'];
  final problems = <String>[];
  final premium = pass['premium'];
  if (premium is! List<dynamic> || premium.isEmpty) {
    problems.add('$label: pass needs a Premium reward for its milestones');
  } else {
    if (premium.length != milestones) {
      problems.add(
        '$label: pass needs one Premium reward for each milestone '
        '(${premium.length} for $milestones)',
      );
    }
    for (var i = 0; i < premium.length; i++) {
      if (!_rewardIsSound(premium[i], mayBeEmpty: false)) {
        problems.add('$label: Premium reward ${i + 1} is empty or too big');
      }
    }
  }
  final plus = pass['plus'];
  if (plus == null) return problems;
  if (plus is! Map<String, dynamic>) {
    return [...problems, '$label: pass "plus" must be settings'];
  }
  final bonus = plus['bonus_percent'] ?? 0;
  if (bonus is! int || bonus < 0 || bonus > 100) {
    problems.add('$label: pass bonus_percent must be 0 to 100');
  }
  final endless = plus['endless'];
  if (endless != null) {
    final every = endless is Map<String, dynamic> ? endless['every'] : null;
    // Never so close together that a few merges pay a step.
    if (every is! int || every < 50) {
      problems.add('$label: the endless track needs "every" of 50 or more');
    }
    if (!_rewardIsSound(endless, mayBeEmpty: false)) {
      problems.add('$label: the endless reward is empty or too big');
    } else if (((endless as Map<String, dynamic>)['pearls'] ?? 0) != 0) {
      // A track with no end must not pay the premium currency for ever.
      problems.add('$label: the endless track cannot give Pearls');
    }
  }
  return problems;
}

/// Plain-English problems with "season_pass" in the offers file
/// ([offersJson]); empty if it is sound or there is none.
List<String> seasonPassProblems(Map<String, dynamic> offersJson) {
  final pass = offersJson['season_pass'];
  if (pass == null) return const [];
  if (pass is! Map<String, dynamic>) {
    return ['Season pass: it must be a group of settings'];
  }
  final problems = <String>[];
  final premium = pass['premium_product'];
  final plus = pass['plus_product'];
  final taken = {
    if (offersJson['offer_products'] case final List<dynamic> ids) ...ids,
    if (offersJson['treasure_jar'] case {'sizes': final List<dynamic> sizes})
      for (final s in sizes)
        if (s case {'product_id': final Object id}) id,
  };
  if (premium is! String || plus is! String || premium == plus) {
    problems.add('Season pass: it needs two different store products');
  } else if (taken.contains(premium) || taken.contains(plus)) {
    problems.add('Season pass: its products are used for something else');
  }
  final text = pass['text'];
  for (final key in seasonPassTextKeys) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is! String || words.isEmpty || words.length > 140) {
      problems.add(
        'Season pass: text "$key" is missing or longer than 140 letters',
      );
    }
  }
  for (final (key, place) in const [
    ('buy_premium', '{price}'),
    ('buy_plus', '{price}'),
    ('upgrade', '{price}'),
    ('at_points', '{points}'),
    ('pearls', '{n}'),
    ('manna', '{n}'),
    ('talents', '{n}'),
    ('plus_note', '{percent}'),
    ('endless', '{reward}'),
    ('endless', '{points}'),
  ]) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is String && !words.contains(place)) {
      problems.add('Season pass: text "$key" must contain $place');
    }
  }
  return problems;
}
