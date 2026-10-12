import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/study_guides_validator.dart';
import 'package:whispers_of_joppa/domain/study_guides.dart';

Map<String, dynamic> _file() =>
    jsonDecode(File('content/study_guides.json').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _chapters() =>
    chapterIdsOf(jsonDecode(File('content/chapters.json').readAsStringSync()));

void main() {
  test('the game\'s own guides are sound: one for every chapter', () {
    expect(studyGuidesProblems(_file(), chapterIds: _chapters()), isEmpty);
    expect(studyGuidesFrom(_file()).map((g) => g.chapter).toSet(), _chapters());
  });

  test('a guide opens only when its chapter is finished', () {
    final guides = studyGuidesFrom(_file());
    expect(studyGuideOpen(guides.first, const <String>[]), isFalse);
    expect(studyGuideOpen(guides.first, const ['ch1']), isTrue);
    expect(studyGuideOpen(guides[1], const ['ch1']), isFalse);
  });

  test('as words to paste: title, rumor, verse with its source, questions', () {
    const guide = StudyGuide(
      chapter: 'ch1',
      title: 'T',
      rumor: 'R',
      verse: 'V',
      ref: 'John 7:24 (KJV)',
      questions: ['a', 'b', 'c'],
    );
    expect(
      studyGuideAsText(
        guide,
        rumor: 'The rumor',
        verse: 'The verse',
        questions: 'Talk it over',
        footer: 'From the game',
      ),
      'T\n\nThe rumor: R\n\nThe verse: "V" John 7:24 (KJV)\n\n'
      'Talk it over:\n1. a\n2. b\n3. c\n\nFrom the game',
    );
  });

  test('no file means no guides', () {
    expect(studyGuidesFrom(null), isEmpty);
  });

  test('problems are named', () {
    final bad = _file();
    final guides = (bad['guides'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    guides[0]['ref'] = 'Proverbs 15:1 (NIV)';
    guides[1]['chapter'] = 'ch99';
    guides[2]['questions'] = ['only one'];
    (bad['text'] as Map<String, dynamic>).remove('copy');
    final problems = studyGuidesProblems(bad, chapterIds: _chapters());
    expect(problems, hasLength(4));
    expect(studyGuidesProblems(null, chapterIds: const {}), hasLength(1));
  });
}
