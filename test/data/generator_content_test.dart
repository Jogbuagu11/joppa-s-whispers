import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/event_validator.dart';
import 'package:whispers_of_joppa/data/generator_type_validator.dart';

import '../support/content_fixtures.dart';

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

/// The real content with one file changed by [change].
List<String> _problemsWith(String file, void Function(dynamic json) change) {
  final files = Map<String, Object?>.of(realContent().files);
  final copy = jsonDecode(jsonEncode(files[file]));
  change(copy);
  files[file] = copy;
  return ContentBundle(
    version: 99,
    format: supportedContentFormat,
    files: files,
  ).problems();
}

void main() {
  test('content checks: each kind must say its numbers', () {
    List<String> check(Map<String, dynamic> gen) {
      final problems = <String>[];
      checkGeneratorType('g', gen, problems);
      return problems;
    }

    expect(check({}), isEmpty);
    expect(
      check({'type': 'charged', 'charges': 6, 'cooldown_seconds': 7200}),
      isEmpty,
    );
    expect(check({'type': 'sideways'}).join(), contains('unknown type'));
    expect(check({'type': 'charged'}).join(), contains('needs charges'));
    expect(
      check({'type': 'charged', 'charges': 3}).join(),
      contains('needs cooldown_seconds'),
    );
    expect(check({'type': 'free'}).join(), contains('needs interval_seconds'));
    expect(check({'type': 'temporary'}).join(), contains('needs taps'));
  });

  test('the real content passes, at the format this build plays', () {
    expect(realContent().problems(), isEmpty);
    expect((_read('version') as Map<String, dynamic>)['format'], 3);
    expect(supportedContentFormat, 3);
  });

  test('a temporary generator cannot start on the board (it would come '
      'back each time it was used up)', () {
    final problems = _problemsWith('starting_board', (json) {
      ((json as Map<String, dynamic>)['generators'] as List<dynamic>).add({
        'generator_id': 'gen_loaves',
        'col': 3,
        'row': 0,
      });
    });
    expect(problems.join('\n'), contains('temporary generator'));
  });

  test('a level may only give a temporary generator', () {
    final problems = _problemsWith('levels', (json) {
      final levels = (json as Map<String, dynamic>)['levels'] as List<dynamic>;
      (levels.first as Map<String, dynamic>)['generator'] = 'gen_pantry';
    });
    expect(problems.join('\n'), contains('not a temporary'));
  });

  test('a level cannot give an item that does not exist', () {
    final problems = _problemsWith('levels', (json) {
      final levels = (json as Map<String, dynamic>)['levels'] as List<dynamic>;
      (levels.first as Map<String, dynamic>)['items'] = ['golden_goose'];
    });
    expect(problems.join('\n'), contains('unknown item "golden_goose"'));
  });

  test('an event generator must be the standard kind', () {
    final event =
        jsonDecode(jsonEncode((_read('events') as List<dynamic>).first))
            as Map<String, dynamic>;
    expect(eventProblems(event), isEmpty);
    ((event['config'] as Map<String, dynamic>)['generator']
            as Map<String, dynamic>)['type'] =
        'charged';
    expect(eventProblems(event).join('\n'), contains('standard kind'));
  });
}
