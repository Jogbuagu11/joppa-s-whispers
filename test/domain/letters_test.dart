import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/letters.dart';

LetterModel _letter(String id, int chapter) => LetterModel(
  id: id,
  chapter: chapter,
  title: 'Title $id',
  body: 'Body $id',
  reference: 'Ref $id',
);

void main() {
  test('fromJson reads every field', () {
    final l = LetterModel.fromJson({
      'id': 'letter_01',
      'chapter': 1,
      'title': 'The oven niche',
      'body': 'My Naomi…',
      'reference': '1 John 4:18 (KJV)',
    });
    expect(l.id, 'letter_01');
    expect(l.chapter, 1);
    expect(l.title, 'The oven niche');
    expect(l.body, 'My Naomi…');
    expect(l.reference, '1 John 4:18 (KJV)');
  });

  group('keepsakePages', () {
    final letters = [
      _letter('c2_a', 2),
      _letter('c1_a', 1),
      _letter('c1_b', 1),
    ];

    test('orders by chapter, keeping content order within a chapter', () {
      final pages = keepsakePages(letters, {});
      expect([for (final p in pages) p.letter.id], ['c1_a', 'c1_b', 'c2_a']);
    });

    test('marks only the found letters', () {
      final pages = keepsakePages(letters, {'c1_b', 'unknown'});
      expect([for (final p in pages) p.found], [false, true, false]);
    });

    test('an empty book has no pages', () {
      expect(keepsakePages([], {'x'}), isEmpty);
    });
  });

  test('lettersFoundCount counts found letters that exist', () {
    final letters = [_letter('a', 1), _letter('b', 1)];
    expect(lettersFoundCount(letters, {}), 0);
    expect(lettersFoundCount(letters, {'a', 'zzz'}), 1);
    expect(lettersFoundCount(letters, {'a', 'b'}), 2);
  });
}
