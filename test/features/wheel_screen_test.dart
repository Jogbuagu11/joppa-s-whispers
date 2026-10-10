import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/chance.dart';
import 'package:whispers_of_joppa/domain/wheel.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_controller.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_painter.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_screen.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

const _rules = WheelRules(
  freeSpinsPerDay: 1,
  adSpinsPerDay: 1,
  pearlSpinBase: 5,
  pearlSpinStep: 5,
  pearlSpinsPerDay: 1,
  prizes: [
    Prize(id: 'manna', name: '20 Manna', weight: 3, manna: 20),
    Prize(id: 'pearls', name: '3 Pearls', weight: 1, pearls: 3, freeOnly: true),
  ],
);
const _text = {
  'wheel_title': 'The Blessing Wheel',
  'spin_free': 'Spin (free today)',
  'spin_ad': 'Watch an ad to spin',
  'spin_pearls': 'Spin for {pearls} Pearls',
  'spins_done': 'Come back tomorrow',
  'see_odds': 'See odds',
  'odds_title': 'What the wheel gives',
  'odds_free': 'Free and ad spins',
  'odds_paid': 'Spins for Pearls',
  'odds_note': 'Drawn by exactly these chances.',
  'won_title': 'You received',
  'won_button': 'Thank you',
  'close': 'Close',
};

class _First implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}

void main() {
  late int pearls;
  late List<String> given;

  WheelController wheel({bool paidAllowed = true, bool ads = false}) =>
      WheelController(
        rules: _rules,
        extras: SaveExtras(),
        paidAllowed: paidAllowed,
        pearls: () => pearls,
        spendPearls: (n) {
          if (n > pearls) return false;
          pearls -= n;
          return true;
        },
        grant: (prize) => given.add(prize.id),
        adReady: () => ads,
        watchAd: () async => true,
        random: _First(),
      );

  Future<void> show(WidgetTester tester, WheelController controller) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: WheelScreen(controller: controller, text: _text),
      ),
    );
  }

  setUp(() {
    pearls = 5;
    given = [];
  });

  testWidgets('the prizes and their chances are on the screen before any '
      'spin, and in the odds panel for both kinds of spin', (tester) async {
    final controller = wheel();
    await show(tester, controller);
    expect(tester.takeException(), isNull);
    expect(find.text('20 Manna'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('odds_manna'))).data,
      '75%',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('odds_pearls'))).data,
      '25%',
    );

    await tester.tap(find.byKey(const Key('wheel_see_odds')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('odds_panel')), findsOneWidget);
    expect(find.byKey(const Key('odds_paid')), findsOneWidget);
    // On a Pearl spin the only prize is the Manna: 100%, and no Pearls.
    final paid = find.descendant(
      of: find.byKey(const Key('odds_paid')),
      matching: find.byType(Text),
    );
    final words = [for (final t in tester.widgetList<Text>(paid)) t.data];
    expect(words, contains('100%'));
    expect(words, isNot(contains('3 Pearls')));
    await tester.tap(find.byKey(const Key('odds_close')));
    await tester.pumpAndSettle();
    controller.dispose();
  });

  testWidgets('a free spin turns the wheel, names the prize and is then '
      'gone for the day', (tester) async {
    final controller = wheel();
    await show(tester, controller);
    expect(find.byKey(const Key('wheel_spin_ad')), findsNothing);
    await tester.tap(find.byKey(const Key('wheel_spin_free')));
    await tester.pump();
    // While it turns nothing else can be spun.
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('wheel_spin_pearls')))
          .onPressed,
      isNull,
    );
    await tester.pumpAndSettle();
    expect(given, ['manna']);
    expect(
      tester.widget<Text>(find.byKey(const Key('wheel_prize_name'))).data,
      '20 Manna',
    );
    await tester.tap(find.byKey(const Key('wheel_prize_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wheel_spin_free')), findsNothing);

    // The Pearl spin: its price is on the button; then nothing is left.
    expect(find.text('Spin for 5 Pearls'), findsOneWidget);
    await tester.tap(find.byKey(const Key('wheel_spin_pearls')));
    await tester.pumpAndSettle();
    expect(pearls, 0);
    expect(given, ['manna', 'manna']);
    await tester.tap(find.byKey(const Key('wheel_prize_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wheel_done')), findsOneWidget);
    controller.dispose();
  });

  testWidgets('without the Pearls the Pearl spin is greyed out; where paid '
      'chance is forbidden it is not there, nor its odds', (tester) async {
    pearls = 0;
    final poor = wheel();
    await show(tester, poor);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('wheel_spin_pearls')))
          .onPressed,
      isNull,
    );
    poor.dispose();

    final blocked = wheel(paidAllowed: false, ads: true);
    await tester.pumpWidget(const SizedBox());
    await show(tester, blocked);
    expect(find.byKey(const Key('wheel_spin_pearls')), findsNothing);
    expect(find.byKey(const Key('wheel_spin_ad')), findsOneWidget);
    await tester.tap(find.byKey(const Key('wheel_see_odds')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('odds_paid')), findsNothing);
    blocked.dispose();
  });

  test('a slice is as wide as its chance, and its middle is where the '
      'wheel stops', () {
    final odds = oddsFor(_rules.prizes, paid: false);
    expect(sliceMiddle(odds, 0), closeTo(0.375, 1e-9));
    expect(sliceMiddle(odds, 1), closeTo(0.875, 1e-9));
  });
}
