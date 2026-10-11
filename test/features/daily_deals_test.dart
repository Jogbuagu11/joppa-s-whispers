import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/deals.dart';
import 'package:whispers_of_joppa/features/shop/daily_deals.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

const _config = DealsConfig(
  free: [DailyDeal(id: 'gift', name: '15 Manna', manna: 15)],
  forPearls: [
    DailyDeal(
      id: 'glass',
      name: 'Hourglass',
      pearlPrice: 10,
      items: ['hourglass_02'],
    ),
  ],
  pearlDealsPerDay: 1,
);
const _text = {
  'deals_title': "Today's deals",
  'deal_free': 'Free',
  'deal_price': '{pearls} Pearls',
  'deal_taken': 'Taken',
  'deals_note': 'New deals every day.',
};

void main() {
  testWidgets('the free gift is taken once; a Pearl deal needs its Pearls, '
      'takes them once and gives what it says', (tester) async {
    var now = DateTime(2026, 10, 12, 9);
    final extras = SaveExtras();
    final pearls = ValueNotifier<int>(4);
    final given = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyDeals(
            config: _config,
            extras: extras,
            text: _text,
            pearls: pearls,
            spendPearls: (n) {
              if (n > pearls.value) return false;
              pearls.value -= n;
              return true;
            },
            give: (deal) => given.add(deal.id),
            clock: () => now,
          ),
        ),
      ),
    );
    FilledButton button(String id) =>
        tester.widget<FilledButton>(find.byKey(Key('deal_$id')));
    expect(find.text('15 Manna'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('10 Pearls'), findsOneWidget);
    // Too few Pearls: greyed out.
    expect(button('glass').onPressed, isNull);

    await tester.tap(find.byKey(const Key('deal_gift')));
    await tester.pump();
    expect(given, ['gift']);
    expect(find.text('Taken'), findsOneWidget);
    expect(button('gift').onPressed, isNull);

    pearls.value = 25;
    await tester.pump();
    await tester.tap(find.byKey(const Key('deal_glass')));
    await tester.pump();
    expect(given, ['gift', 'glass']);
    expect(pearls.value, 15);
    expect(button('glass').onPressed, isNull);
    expect(find.text('Taken'), findsNWidgets(2));

    // The next day both can be taken again.
    now = now.add(const Duration(days: 1));
    extras.write('other', {'x': 1});
    await tester.pump();
    expect(button('gift').onPressed, isNotNull);
    expect(find.text('Taken'), findsNothing);
    pearls.dispose();
    extras.dispose();
  });

  test('a deal that is not one of today\'s cannot be taken, and a taken '
      'deal is not given again by winding the clock back and forth', () {
    var now = DateTime(2026, 10, 12, 9);
    final extras = SaveExtras();
    final pearls = ValueNotifier<int>(50);
    final given = <String>[];
    final deals = DailyDeals(
      config: _config,
      extras: extras,
      text: _text,
      pearls: pearls,
      spendPearls: (n) {
        pearls.value -= n;
        return true;
      },
      give: (deal) => given.add(deal.id),
      clock: () => now,
    );
    const stranger = DailyDeal(id: 'old', name: 'Old', manna: 99);
    expect(deals.take(stranger), isFalse);
    expect(given, isEmpty);
    expect(pearls.value, 50);

    final gift = _config.free.single;
    expect(deals.take(gift), isTrue);
    expect(deals.take(gift), isFalse);
    // Forward a day (a new gift, as on any new day), then back again.
    now = now.add(const Duration(days: 1));
    expect(deals.take(gift), isTrue);
    now = now.subtract(const Duration(days: 1));
    expect(deals.take(gift), isFalse);
    now = now.add(const Duration(days: 1));
    expect(deals.take(gift), isFalse);
    expect(given, ['gift', 'gift']);
    pearls.dispose();
    extras.dispose();
  });
}
