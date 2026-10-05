import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/scene_validator.dart';

List<Map<String, dynamic>> _characters() => [
  {
    'id': 'silas',
    'name': 'Silas',
    'expressions': ['neutral', 'happy'],
  },
];

Map<String, dynamic> _scene() => {
  'id': 'ch1_s_01',
  'background': 'loc_harbor_dusk',
  'lines': [
    for (final text in ['Little loaf.', 'You came.', 'Sit.', 'Eat.'])
      {'speaker': 'silas', 'expression': 'happy', 'text': text},
  ],
};

List<String> _check(List<Map<String, dynamic>> scenes) {
  final problems = <String>[];
  checkScenes(scenes: scenes, characters: _characters(), problems: problems);
  return problems;
}

Map<String, dynamic> _line(Map<String, dynamic> scene) =>
    (scene['lines'] as List<dynamic>).first as Map<String, dynamic>;

void main() {
  test('a good scene has no problems', () {
    expect(_check([_scene()]), isEmpty);
  });

  test('an unknown speaker is reported', () {
    final s = _scene();
    _line(s)['speaker'] = 'nobody';
    expect(_check([s]).single, contains('unknown character "nobody"'));
  });

  test('an expression the character does not have is reported', () {
    final s = _scene();
    _line(s)['expression'] = 'angry';
    expect(_check([s]).single, contains('silas has no "angry" expression'));
  });

  test('missing and over-long text are reported', () {
    final s = _scene();
    _line(s)['text'] = ' ';
    expect(_check([s]).single, contains('missing text'));
    _line(s)['text'] = 'x' * 141;
    expect(_check([s]).single, contains('over 140 characters'));
  });

  test('too few or too many lines are reported', () {
    final none = _scene()..['lines'] = <dynamic>[];
    expect(_check([none]).single, contains('has 0 lines'));
    final many = _scene();
    final lines = many['lines'] as List<dynamic>;
    many['lines'] = [for (int i = 0; i < 4; i++) ...lines];
    expect(_check([many]).single, contains('has 16 lines'));
  });

  test('bad ids, duplicate ids and bad backgrounds are reported', () {
    final bad = _scene()
      ..['id'] = 'Scene One'
      ..['background'] = 'harbor';
    final problems = _check([_scene(), _scene(), bad]);
    expect(problems, contains(contains('used more than once')));
    expect(problems, contains(contains('lowercase snake_case')));
    expect(problems, contains(contains('loc_some_place')));
  });
}
