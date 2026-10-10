// Checks the kind-of-generator fields in content/generators.json. Pure Dart.

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
