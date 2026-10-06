import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/letters.dart';
import 'package:whispers_of_joppa/features/letters/letters_screen.dart';

const _letters = [
  LetterModel(
    id: 'letter_01',
    chapter: 1,
    title: 'The oven niche',
    body: 'My Naomi, open the shutters.',
    reference: '1 John 4:18 (KJV)',
  ),
  LetterModel(
    id: 'letter_02',
    chapter: 1,
    title: 'Behind the loose brick',
    body: 'His mercies are new every morning.',
    reference: 'Lamentations 3:22–23 (KJV)',
  ),
];

Future<void> _show(WidgetTester tester, Set<String> found) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: LettersScreen(letters: _letters, foundLetterIds: found),
    ),
  );
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

void main() {
  testWidgets('with nothing found, every page is locked', (tester) async {
    await _show(tester, {});
    expect(tester.takeException(), isNull);
    expect(_text(tester, 'letters_progress'), '0 of 2 found');
    expect(_text(tester, 'letter_title_letter_01'), 'Not found yet');
    expect(find.text('The oven niche'), findsNothing);

    // A locked page cannot be opened.
    await tester.tap(find.byKey(const Key('letter_tile_letter_01')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('letter_reader')), findsNothing);
  });

  testWidgets('a found letter shows its title and opens in full', (
    tester,
  ) async {
    await _show(tester, {'letter_01'});
    expect(_text(tester, 'letters_progress'), '1 of 2 found');
    expect(_text(tester, 'letter_title_letter_01'), 'The oven niche');
    expect(_text(tester, 'letter_title_letter_02'), 'Not found yet');

    await tester.tap(find.byKey(const Key('letter_tile_letter_01')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('letter_reader')), findsOneWidget);
    expect(_text(tester, 'letter_body'), 'My Naomi, open the shutters.');
    expect(_text(tester, 'letter_reference'), '1 John 4:18 (KJV)');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('letters_screen')), findsOneWidget);
  });
}
