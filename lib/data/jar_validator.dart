// Checks the jars and the small chance lists of content/chance.json.
// Pure Dart.
import 'package:whispers_of_joppa/data/chance_validator.dart';

/// Checks the jars: their items, prices and prizes, and that nothing paid
/// for with Pearls ([paidPrizes]: the wheel's prizes for a Pearl spin) can
/// lead to Pearls through a jar.
void checkJars(
  Map<String, dynamic> jars,
  Object? chainsJson, {
  required Set<Object?> itemIds,
  required Set<Object?> temporary,
  required List<dynamic> paidPrizes,
  required List<String> problems,
}) {
  final every = jars['clay_every_orders'];
  if (every is! int || every < 0) {
    problems.add('Jars: clay_every_orders must be a whole number, 0 or more');
  }
  final kinds = jars['kinds'] as Map<String, dynamic>;
  // item_id -> the kind of jar its "use" says it is.
  final jarItems = {
    for (final chain in chainsJson as List<dynamic>)
      for (final tier
          in (chain as Map<String, dynamic>)['tiers'] as List<dynamic>)
        if ((tier as Map<String, dynamic>)['use'] case {
          'jar': final Object kind,
        })
          tier['item_id']: kind,
  };
  for (final unknown in jarItems.entries) {
    if (!kinds.containsKey(unknown.value)) {
      problems.add(
        'Item ${unknown.key}: "${unknown.value}" is not a kind of jar',
      );
    }
  }
  final order = kinds[jars['order_jar']];
  if (order is! Map<String, dynamic> || order['pearl_price'] != null) {
    problems.add('Jars: order_jar must be a kind of jar that is not for sale');
  }
  // The jars that can hold Pearls, by their item.
  final pearlJars = {
    for (final entry in kinds.entries)
      if (((entry.value as Map<String, dynamic>)['prizes'] as List<dynamic>?)
              ?.any((p) => (p as Map<String, dynamic>)['pearls'] != null) ??
          false)
        entry.value['item'],
  };
  for (final prize in paidPrizes) {
    final items = (prize as Map<String, dynamic>)['items'] as List<dynamic>?;
    if (items != null && items.any(pearlJars.contains)) {
      problems.add(
        'Wheel prize ${prize['id']}: a prize of a Pearl spin cannot be a jar '
        'that may hold Pearls',
      );
    }
  }
  for (final entry in kinds.entries) {
    final kind = entry.value as Map<String, dynamic>;
    final what = 'Jar "${entry.key}"';
    if (jarItems[kind['item']] != entry.key) {
      problems.add('$what: its item must be an item whose use is this jar');
    }
    final price = kind['pearl_price'];
    if (price != null && (price is! int || price < 1)) {
      problems.add('$what: pearl_price must be 1 or more');
    }
    checkPrizes(
      what,
      kind['prizes'],
      itemIds: itemIds,
      temporaryGeneratorIds: temporary,
      problems: problems,
    );
    for (final prize in kind['prizes'] as List<dynamic>? ?? const []) {
      final items = (prize as Map<String, dynamic>)['items'] as List<dynamic>?;
      // A jar in a jar would be a second draw nobody was shown the odds of.
      if (items != null && items.any(jarItems.containsKey)) {
        problems.add('$what: a jar cannot hold another jar');
      }
      // A jar that can be bought never holds Pearls at all.
      if (price != null && prize['pearls'] != null) {
        problems.add('$what: a jar that is sold cannot hold Pearls');
      }
    }
  }
}

/// Checks a list of outcomes (each a number under [key], and a weight): each number
/// at least [least] and used once, the first being the plain outcome.
void checkSteps(
  String what,
  Object? steps,
  String key, {
  required int least,
  required List<String> problems,
}) {
  if (steps is! List<dynamic> || steps.isEmpty) {
    problems.add('$what: has no outcomes');
    return;
  }
  final seen = <Object?>{};
  for (final entry in steps) {
    final step = entry as Map<String, dynamic>;
    final amount = step[key];
    final weight = step['weight'];
    if (amount is! int || amount < least || amount > 9 || !seen.add(amount)) {
      problems.add('$what: $key "$amount" must be $least to 9, used once');
    }
    if (weight is! int || weight < 1) {
      problems.add('$what: every weight must be 1 or more');
    }
  }
  if ((steps.first as Map<String, dynamic>)[key] != least) {
    problems.add('$what: the first outcome must be the plain one ($least)');
  }
}
