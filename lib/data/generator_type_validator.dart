// Checks the kind-of-generator fields in content/generators.json, and the
// "use" of items that can be used. Pure Dart.

const _kinds = {'standard', 'charged', 'free', 'temporary'};

/// Adds a plain-English line to [problems] for every mistake in how
/// generator [id] says it behaves.
void checkGeneratorType(
  Object? id,
  Map<String, dynamic> gen,
  List<String> problems,
) {
  final type = gen['type'] ?? 'standard';
  if (!_kinds.contains(type)) {
    problems.add('Generator $id: unknown type "$type"');
    return;
  }
  void need(String field, {int least = 1}) {
    final value = gen[field];
    if (value is! int || value < least) {
      problems.add(
        'Generator $id: a $type generator needs $field of $least or more',
      );
    }
  }

  switch (type) {
    case 'charged':
      need('charges');
      need('cooldown_seconds', least: 60);
    case 'free':
      need('interval_seconds', least: 60);
      final waiting = gen['max_waiting'];
      if (waiting != null && (waiting is! int || waiting < 1)) {
        problems.add('Generator $id: max_waiting must be 1 or more');
      }
    case 'temporary':
      need('taps');
  }
}

/// Adds a line to [problems] if an item's "use" ([what] names the item) is
/// not one the game understands.
void checkItemUse(String what, Object? use, List<String> problems) {
  if (use == null) return;
  if (use is! Map<String, dynamic>) {
    problems.add('$what: use must be a record');
    return;
  }
  final manna = use['manna'];
  final seconds = use['skip_seconds'];
  final all = use['skip_all'];
  if (manna != null && (manna is! int || manna < 1)) {
    problems.add('$what: use.manna must be 1 or more');
  }
  if (seconds != null && (seconds is! int || seconds < 1)) {
    problems.add('$what: use.skip_seconds must be 1 or more');
  }
  if (all != null && all is! bool) {
    problems.add('$what: use.skip_all must be true or false');
  }
  for (final key in ['split', 'wild']) {
    final value = use[key];
    if (value != null && value is! bool) {
      problems.add('$what: use.$key must be true or false');
    }
  }
  final kinds = [
    manna != null,
    seconds != null || all == true,
    use['split'] == true,
    use['wild'] == true,
  ].where((kind) => kind).length;
  if (kinds != 1) {
    problems.add(
      '$what: use must do exactly one thing: give Manna, skip time, split '
      'or be a wildcard',
    );
  }
}

/// Adds a line to [problems] if generator [id]'s rare side chain is not a
/// known chain with a sensible chance.
void checkRareDrop(
  Object? id,
  Map<String, dynamic> gen,
  Set<String> chainIds,
  List<String> problems,
) {
  final rare = gen['rare'];
  if (rare == null) return;
  if (rare is! Map<String, dynamic>) {
    problems.add('Generator $id: rare must be a record');
    return;
  }
  if (!chainIds.contains(rare['chain_id'])) {
    problems.add(
      'Generator $id: rare chain "${rare['chain_id']}" does not exist',
    );
  }
  if (rare['chain_id'] == gen['chain_id']) {
    problems.add('Generator $id: its rare chain must not be its own chain');
  }
  final chance = rare['chance'];
  if (chance is! num || chance <= 0 || chance > 0.5) {
    problems.add('Generator $id: rare chance must be above 0 and at most 0.5');
  }
}
