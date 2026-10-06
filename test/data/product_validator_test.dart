import 'package:flutter_test/flutter_test.dart';

import 'validator_fixture.dart';

void main() {
  test('product problems are reported', () {
    final c = validContent();
    c['products'] = [
      {'id': 'Pearls', 'type': 'gift', 'pearls': -5},
      {'id': 'empty_pack', 'type': 'consumable'},
      {'id': 'empty_pack', 'type': 'consumable', 'manna': 10},
    ];
    final problems = checkContent(c);
    expect(problems, contains(contains('lowercase snake_case')));
    expect(
      problems,
      contains(contains('type must be consumable or non_consumable')),
    );
    expect(problems, contains(contains('pearls must be a whole number')));
    expect(problems, contains(contains('empty_pack: gives nothing')));
    expect(problems, contains(contains('used more than once')));
  });
}
