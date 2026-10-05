import 'package:flutter_test/flutter_test.dart';

import 'validator_fixture.dart';

List<Map<String, dynamic>> _steps(Map<String, Object?> c) =>
    (c['tutorial'] as List<dynamic>).cast<Map<String, dynamic>>();

void main() {
  test('unknown speaker, long text and bad free_manna are reported', () {
    final c = validContent();
    _steps(c)[0]
      ..['speaker'] = 'nobody'
      ..['text'] = 'x' * 121
      ..['free_manna'] = 'yes';
    final problems = checkContent(c);
    expect(problems, contains(contains('unknown character "nobody"')));
    expect(problems, contains(contains('text is over 120 characters')));
    expect(problems, contains(contains('free_manna must be true or false')));
  });

  test('unknown trigger, order and task are reported', () {
    final c = validContent();
    _steps(c)[0]['done_when'] = {'type': 'dance'};
    _steps(c)[1]['done_when'] = {'type': 'order_delivered', 'id': 'ch9_o_1'};
    final problems = checkContent(c);
    expect(problems, contains(contains('unknown done_when type "dance"')));
    expect(problems, contains(contains('unknown order "ch9_o_1"')));

    final d = validContent();
    _steps(d)[1]['done_when'] = {'type': 'task_done', 'id': 'nope'};
    expect(checkContent(d).single, contains('unknown task "nope"'));
  });

  test(
    'an id on a trigger that takes none, and duplicate ids, are reported',
    () {
      final c = validContent();
      _steps(c)[0]['done_when'] = {'type': 'merge', 'id': 'ch1_o_001'};
      _steps(c)[1]['id'] = 'tut_merge';
      final problems = checkContent(c);
      expect(problems, contains(contains('takes no id')));
      expect(problems, contains(contains('used more than once')));
    },
  );

  test('ending problems are reported', () {
    final c = validContent();
    final endings = (c['endings'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    endings[0]
      ..['title'] = 'x' * 31
      ..['body'] = ' '
      ..['button'] = 'x' * 17;
    c['endings'] = [
      ...endings,
      {'chapter_id': 'ch7', 'title': 'T', 'body': 'B', 'button': 'OK'},
    ];
    final problems = checkContent(c);
    expect(problems, contains(contains('title is over 30 characters')));
    expect(problems, contains(contains('missing body')));
    expect(problems, contains(contains('button is over 16 characters')));
    expect(problems, contains(contains('unknown chapter "ch7"')));
  });
}
