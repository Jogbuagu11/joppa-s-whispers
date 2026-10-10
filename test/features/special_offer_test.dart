import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/offers_validator.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/features/shop/special_offer.dart';

import '../support/store_fakes.dart';

dynamic _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

const _json = {
  'title': 'Joppa Special',
  'subtitle': 'Pearls from the harbor market',
  'picture': 'assets/ui/none.jpg',
  'no_thanks': 'No thanks',
  'unavailable': 'The market is closed just now.',
  'pearls_word': 'Pearls',
  'button': 'Joppa Special',
  'packs': [
    {'product_id': 'small', 'name': "Fisher's purse"},
    {'product_id': 'middle', 'name': "Merchant's chest", 'featured': true},
    {'product_id': 'gone', 'name': 'Not sold any more'},
  ],
};

void main() {
  test('the special is read from content; anything else is no special', () {
    final offer = SpecialOffer.fromJson(_json);
    expect(offer?.title, 'Joppa Special');
    expect(
      [for (final p in offer?.packs ?? const []) p.productId],
      ['small', 'middle', 'gone'],
    );
    expect(offer?.packs[1].featured, isTrue);
    expect(offer?.packs[0].featured, isFalse);
    expect(SpecialOffer.fromJson(null), isNull);
    expect(SpecialOffer.fromJson({'title': 'x'}), isNull);
  });

  testWidgets('each pack shows exactly its Pearls at the store\'s price; '
      'tapping one buys it through the shop; "No thanks" closes it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = FakeStore();
    final shop =
        PurchaseCoordinator(store: store, backend: FakePurchaseBackend())
          ..products = const {
            'small': ProductModel(id: 'small', consumable: true, pearls: 25),
            'middle': ProductModel(id: 'middle', consumable: true, pearls: 140),
          };
    final started = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSpecialOffer(
              context,
              // Safe: the record above is a whole special.
              offer: SpecialOffer.fromJson(_json)!,
              shop: shop,
              onBuy: started.add,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('special_offer')), findsOneWidget);
    expect(find.text('Joppa Special'), findsOneWidget);
    // A pack the game does not know the contents of is not shown.
    expect(find.byKey(const Key('special_pack_small')), findsOneWidget);
    expect(find.byKey(const Key('special_pack_middle')), findsOneWidget);
    expect(find.byKey(const Key('special_pack_gone')), findsNothing);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('140'), findsOneWidget);
    expect(find.text(r'$0.99'), findsNWidgets(2));

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('special_pack_middle')),
        matching: find.byKey(const Key('special_pack_buy')),
      ),
    );
    await tester.pumpAndSettle();
    expect(started, ['middle']);

    await tester.tap(find.byKey(const Key('special_no_thanks')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('special_offer')), findsNothing);

    // The cross closes it too.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('special_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('special_offer')), findsNothing);
  });

  test('the real special names real Pearl packs; the checker catches one '
      'that does not', () {
    final offers = _read('offers') as Map<String, dynamic>;
    List<String> check(void Function(Map<String, dynamic> special) change) {
      final copy = jsonDecode(jsonEncode(offers)) as Map<String, dynamic>;
      change(copy['special'] as Map<String, dynamic>);
      return offersProblems(
        copy,
        chainsJson: _read('chains'),
        productsJson: _read('products'),
      );
    }

    Map<String, dynamic> first(Map<String, dynamic> special) =>
        (special['packs'] as List<dynamic>).first as Map<String, dynamic>;
    expect(check((s) {}), isEmpty);
    expect(check((s) => first(s)['product_id'] = 'no_such_pack'), isNotEmpty);
    expect(check((s) => first(s)['name'] = ''), isNotEmpty);
    expect(check((s) => s['title'] = ''), isNotEmpty);
    expect(check((s) => (s['packs'] as List<dynamic>).clear()), isNotEmpty);
    expect(
      check(
        (s) => first(s)['product_id'] =
            ((s['packs'] as List<dynamic>)[1]
                as Map<String, dynamic>)['product_id'],
      ),
      isNotEmpty,
    );
  });
}
