import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/chance.dart';
import 'package:whispers_of_joppa/domain/jars.dart';
import 'package:whispers_of_joppa/features/wheel/jar_shop.dart';

const _treasure = JarKind(
  id: 'treasure',
  itemId: 'treasurejar_01',
  pearlPrice: 15,
  prizes: [
    Prize(id: 'manna', name: '60 Manna', weight: 3, manna: 60),
    Prize(id: 'talents', name: '150 Talents', weight: 1, talents: 150),
  ],
);
const _text = {
  'jars_title': 'Jars of Clay',
  'see_odds': 'See odds',
  'jar_buy': '{pearls} Pearls',
  'jar_holds': 'It holds one of these:',
  'odds_note': 'Drawn by exactly these chances.',
  'close': 'Close',
  'jar_buy_title': 'Buy a {name}?',
  'jar_buy_yes': 'Buy for {pearls} Pearls',
  'jar_buy_no': 'Not now',
  'pearls_have': 'You have {pearls} Pearls',
};

void main() {
  testWidgets('a jar shows its price, its odds on request, and is bought '
      'only with the Pearls for it', (tester) async {
    final pearls = ValueNotifier<int>(10);
    final bought = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JarShop(
            jars: const [_treasure],
            names: const {'treasure': 'Treasure Jar'},
            text: _text,
            pearls: pearls,
            onBuy: (jar) {
              bought.add(jar.id);
              return true;
            },
          ),
        ),
      ),
    );
    expect(find.text('Treasure Jar'), findsOneWidget);
    expect(find.text('15 Pearls'), findsOneWidget);
    FilledButton buy() =>
        tester.widget<FilledButton>(find.byKey(const Key('jar_buy_treasure')));
    // Too few Pearls: greyed out.
    expect(buy().onPressed, isNull);

    // What it may hold, with chances, before buying.
    await tester.tap(find.byKey(const Key('jar_odds_treasure')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jar_odds_panel')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('odds_manna'))).data,
      '75%',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('odds_talents'))).data,
      '25%',
    );
    await tester.tap(find.byKey(const Key('odds_close')));
    await tester.pumpAndSettle();

    pearls.value = 15;
    await tester.pump();
    expect(buy().onPressed, isNotNull);
    // Buying asks first, with what the jar may hold in view.
    await tester.tap(find.byKey(const Key('jar_buy_treasure')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jar_buy_dialog')), findsOneWidget);
    expect(find.text('Buy a Treasure Jar?'), findsOneWidget);
    expect(find.byKey(const Key('odds_manna')), findsOneWidget);
    await tester.tap(find.byKey(const Key('jar_buy_no')));
    await tester.pumpAndSettle();
    expect(bought, isEmpty);
    await tester.tap(find.byKey(const Key('jar_buy_treasure')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jar_buy_yes')));
    await tester.pumpAndSettle();
    expect(bought, ['treasure']);
    expect(find.text('You have 15 Pearls'), findsOneWidget);
    pearls.dispose();
  });
}
