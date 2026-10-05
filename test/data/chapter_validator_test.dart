import 'package:flutter_test/flutter_test.dart';

import 'validator_fixture.dart';

Map<String, dynamic> _task(Map<String, Object?> c) =>
    (firstOf(c, 'chapters')['tasks'] as List<dynamic>).first
        as Map<String, dynamic>;

void main() {
  test('the small valid set, with a chapter, has no problems', () {
    expect(checkContent(validContent()), isEmpty);
  });

  test('a task costing more than the orders pay is reported', () {
    final c = validContent();
    _task(c)['cost_blessings'] = 2;
    expect(
      checkContent(c).single,
      contains('tasks cost 2 Blessings but its orders only pay 1'),
    );
  });

  test('unknown scene, area and letter are reported', () {
    final c = validContent();
    _task(c)
      ..['scene_id'] = 'nope'
      ..['restores_area'] = 'bakehouse_roof'
      ..['letter_id'] = 'letter_99';
    final problems = checkContent(c);
    expect(problems, contains(contains('unknown scene "nope"')));
    expect(problems, contains(contains('is not in this location')));
    expect(problems, contains(contains('unknown letter "letter_99"')));
  });

  test('a scene or area used by two tasks is reported', () {
    final c = validContent();
    firstOf(c, 'chapters')['tasks'] = <Map<String, dynamic>>[
      _task(c),
      {..._task(c), 'id': 'ch1_t_02'},
    ];
    (firstOf(c, 'orders')['rewards'] as Map<String, dynamic>)['blessings'] = 2;
    final problems = checkContent(c);
    expect(problems, contains(contains('is used by another task')));
    expect(problems, contains(contains('is restored twice')));
  });

  test('bad title, cost and location are reported', () {
    final c = validContent();
    _task(c)
      ..['title'] = 'x' * 33
      ..['cost_blessings'] = 0;
    firstOf(c, 'chapters')
      ..['location_id'] = 'nowhere'
      ..['unlocks_chains'] = ['bakery', 'ghost'];
    final problems = checkContent(c);
    expect(problems, contains(contains('title is over 32 characters')));
    expect(problems, contains(contains('cost_blessings must be 1 or more')));
    expect(problems, contains(contains('unknown location "nowhere"')));
    expect(problems, contains(contains('unknown chain "ghost"')));
  });

  test('an area or letter with a missing field is reported', () {
    final c = validContent();
    ((firstOf(c, 'locations')['areas'] as List<dynamic>).first
            as Map<String, dynamic>)
        .remove('after');
    firstOf(c, 'letters')['body'] = ' ';
    final problems = checkContent(c);
    expect(problems, contains(contains('missing after')));
    expect(problems, contains(contains('missing body')));
  });

  test('bad chapter number, title, beat and empty task list are reported', () {
    final c = validContent();
    _task(c)['beat'] = 'two';
    firstOf(c, 'chapters')
      ..['number'] = 0
      ..['title'] = ' ';
    final problems = checkContent(c);
    expect(problems, contains(contains('number must be 1 or more')));
    expect(problems, contains(contains('missing title')));
    expect(problems, contains(contains('beat must be a whole number')));

    final d = validContent();
    firstOf(d, 'chapters')['tasks'] = <Map<String, dynamic>>[];
    expect(checkContent(d), contains(contains('has no tasks')));
  });
}
