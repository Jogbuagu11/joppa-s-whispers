import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/features/orders/order_card.dart';

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
  Future<void> show(WidgetTester tester, {required bool compact}) async {
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
              height: compact ? 136 : 178,
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
                compact: compact,
              ),
            ),
          ),
        ),
      ),
    );
    // The portrait is not in the test's assets: its initial shows instead.
    await tester.pumpAndSettle();
  }

  Text request(WidgetTester tester) => tester.widget<Text>(
    find.descendant(
      of: find.byKey(const Key('order_text_o1')),
      matching: find.byType(Text),
    ),
  );

  for (final compact in [false, true]) {
    final name = compact ? 'short-phone' : 'usual';
    testWidgets('the $name card fits, and a long request ends in whole '
        'lines', (tester) async {
      await show(tester, compact: compact);
      expect(tester.takeException(), isNull);
      final text = request(tester);
      expect(text.overflow, TextOverflow.ellipsis);
      // As many whole lines as there is room for, and no more.
      final box = tester.getSize(find.byKey(const Key('order_text_o1')));
      final lines = text.maxLines ?? 0;
      expect(lines, greaterThanOrEqualTo(1));
      expect(lines * 9.5 * 1.2, lessThanOrEqualTo(box.height));
      expect((lines + 1) * 9.5 * 1.2, greaterThan(box.height));
    });

    testWidgets('the $name card fits at the largest text size', (tester) async {
      useLargestText(tester);
      await show(tester, compact: compact);
      expect(tester.takeException(), isNull);
      // Whole lines at this size too.
      final box = tester.getSize(find.byKey(const Key('order_text_o1')));
      final lines = request(tester).maxLines ?? 0;
      expect(lines, greaterThanOrEqualTo(1));
      if (lines > 1) {
        expect(lines * 9.5 * maxTextScale * 1.2, lessThanOrEqualTo(box.height));
      }
      // And the full request opens without spilling.
      await tester.tap(find.byKey(const Key('order_text_o1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('order_details')), findsOneWidget);
    });
  }

  testWidgets('the short-phone card leaves out the reward line', (
    tester,
  ) async {
    await show(tester, compact: false);
    expect(find.text('+30 Talents  +2 ✦'), findsOneWidget);
    await show(tester, compact: true);
    expect(find.text('+30 Talents  +2 ✦'), findsNothing);
  });

  testWidgets('tapping the request shows all of it, with the reward', (
    tester,
  ) async {
    await show(tester, compact: true);
    await tester.tap(find.byKey(const Key('order_text_o1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final window = find.byKey(const Key('order_details'));
    expect(window, findsOneWidget);
    expect(
      find.descendant(of: window, matching: find.text(_long)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: window, matching: find.text('+30 Talents  +2 ✦')),
      findsOneWidget,
    );
    // Reading is not delivering.
    expect(delivered, 0);
    await tester.tap(find.byKey(const Key('order_details_close')));
    await tester.pumpAndSettle();
    expect(window, findsNothing);
  });

  testWidgets('Deliver still delivers', (tester) async {
    await show(tester, compact: true);
    await tester.tap(find.byKey(const Key('order_deliver_o1')));
    expect(delivered, 1);
  });
}
