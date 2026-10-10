import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/features/orders/order_card.dart';
import 'package:whispers_of_joppa/features/orders/orders_bar.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../support/comfort_fakes.dart';

// As long as the longest request in the game.
const _long =
    'An oil lamp and a flatbread, Naomi. A visitor should not find a dark '
    'doorway or an empty table in Joppa, whoever they are.';
const _order = OrderModel(
  id: 'o1',
  chapter: 1,
  characterId: 'hannah',
  kind: 'literal',
  items: [
    OrderItem(itemId: 'bakery_01', count: 1),
    OrderItem(itemId: 'bakery_02', count: 2),
    OrderItem(itemId: 'bakery_01', count: 3),
  ],
  talents: 30,
  blessings: 2,
  text: _long,
);
const _items = {
  'bakery_01': ItemModel(
    itemId: 'bakery_01',
    chainId: 'bakery',
    tier: 1,
    name: 'Sheaf',
    asset: '',
  ),
  'bakery_02': ItemModel(
    itemId: 'bakery_02',
    chainId: 'bakery',
    tier: 2,
    name: 'Flour',
    asset: '',
  ),
};

void main() {
  var delivered = 0;

  // One card as it sits on a 320-point phone (a third of the row), asking
  // for three items: the tightest case in the game.
  Future<void> show(WidgetTester tester, {required double height}) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    delivered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 96,
              height: height,
              child: OrderCard(
                order: _order,
                characterName: 'Hannah',
                items: _items,
                placeholderColors: const {},
                haveCounts: const {'bakery_01': 1},
                canDeliver: true,
                canSkip: true,
                onDeliver: () => delivered++,
                onSkip: () {},
              ),
            ),
          ),
        ),
      ),
    );
    // The portrait is not in the test's assets: its initial shows instead.
    await tester.pumpAndSettle();
  }

  Finder words() => find.descendant(
    of: find.byKey(const Key('order_text_o1')),
    matching: find.byType(Text),
  );

  for (final height in [orderCardsMinHeight, orderCardsMaxHeight]) {
    for (final largeText in [false, true]) {
      testWidgets('a ${height.toInt()}pt card fits'
          '${largeText ? ' at the largest text size' : ''}, and a long '
          'request shows whole lines only', (tester) async {
        if (largeText) useLargestText(tester);
        await show(tester, height: height);
        expect(tester.takeException(), isNull);
        // At most two lines on the card; "…" for the rest.
        if (words().evaluate().isNotEmpty) {
          final text = tester.widget<Text>(words());
          expect(text.overflow, TextOverflow.ellipsis);
          expect(text.maxLines, inInclusiveRange(1, 2));
        }
        // The full request opens without spilling.
        await tester.tap(find.byKey(const Key('order_text_o1')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('order_details')), findsOneWidget);
      });
    }
  }

  testWidgets('the card shows a face, not a name or a reward line', (
    tester,
  ) async {
    await show(tester, height: orderCardsMaxHeight);
    expect(find.text('Hannah'), findsNothing);
    expect(find.text('+30 Talents  +2 ✦'), findsNothing);
    // At the usual height two lines of the request are shown.
    expect(tester.widget<Text>(words()).maxLines, 2);
  });

  testWidgets('tapping the request shows all of it: who, what, the reward', (
    tester,
  ) async {
    await show(tester, height: orderCardsMinHeight);
    await tester.tap(find.byKey(const Key('order_text_o1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final window = find.byKey(const Key('order_details'));
    expect(window, findsOneWidget);
    for (final words in ['Hannah', _long, '+30 Talents  +2 ✦']) {
      expect(
        find.descendant(of: window, matching: find.text(words)),
        findsOneWidget,
      );
    }
    // Reading is not delivering.
    expect(delivered, 0);
    await tester.tap(find.byKey(const Key('order_details_close')));
    await tester.pumpAndSettle();
    expect(window, findsNothing);
  });

  testWidgets('Deliver still delivers', (tester) async {
    await show(tester, height: orderCardsMinHeight);
    await tester.tap(find.byKey(const Key('order_deliver_o1')));
    expect(delivered, 1);
  });

  group('sharing the height between the cards and the board', () {
    test('on a tall phone the board is as wide as the screen', () {
      // A 7 by 9 board 420 wide is 540 tall.
      final s = shareHeight(width: 420, height: 700);
      expect(s.board, 540);
      expect(s.cards, orderCardsMaxHeight);
      // With less to spare the cards give way first, down to their least.
      final tighter = shareHeight(width: 420, height: 670);
      expect(tighter.board, 540);
      expect(tighter.cards, 670 - 540 - 6);
    });

    test('on a short phone the cards keep their least and the board takes '
        'the rest', () {
      final s = shareHeight(width: 375, height: 420);
      expect(s.cards, orderCardsMinHeight);
      expect(s.board, 420 - orderCardsMinHeight - 6);
      expect(s.board, lessThan(375 * 9 / 7));
    });

    test('it never asks for more room than there is, or less than none', () {
      for (final height in [0.0, 50.0, 113.0, 114.0, 300.0, 2000.0]) {
        final s = shareHeight(width: 400, height: height);
        expect(s.board, greaterThanOrEqualTo(0));
        if (height >= orderCardsMinHeight + 6) {
          expect(s.cards + s.board + 6, lessThanOrEqualTo(height + 0.001));
        }
      }
    });
  });
}
