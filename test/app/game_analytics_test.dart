import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/game_analytics.dart';
import 'package:whispers_of_joppa/domain/analytics_events.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';

import '../support/analytics_fakes.dart';

const _products = {
  'pearls_tier1': ProductModel(
    id: 'pearls_tier1',
    consumable: true,
    pearls: 25,
  ),
  'starter_pack': ProductModel(
    id: 'starter_pack',
    consumable: false,
    pearls: 100,
  ),
};

PurchaseRecord _p(String tx, String product) =>
    PurchaseRecord(transactionId: tx, productId: product, granted: true);

void main() {
  late FakeAnalytics analytics;
  late DateTime now;
  late GameAnalytics events;

  setUp(() {
    analytics = FakeAnalytics();
    now = DateTime(2026, 10, 5, 12);
    events = GameAnalytics(analytics, clock: () => now);
  });

  test('a session starts once and ends with its length in seconds', () {
    events.sessionStarted();
    events.sessionStarted();
    now = now.add(const Duration(minutes: 3));
    events.sessionEnded();
    events.sessionEnded();
    expect(analytics.names, [
      AnalyticsEvent.sessionStart,
      AnalyticsEvent.sessionEnd,
    ]);
    expect(analytics.events.first.$2, isEmpty);
    expect(analytics.events.last.$2, {'seconds': 180});
  });

  test('a clock that moved backwards never gives a negative length', () {
    events.sessionStarted();
    now = now.subtract(const Duration(hours: 1));
    events.sessionEnded();
    expect(analytics.events.last.$2, {'seconds': 0});
  });

  test('coming back to the app starts a new session', () {
    events
      ..sessionStarted()
      ..sessionEnded()
      ..sessionStarted();
    expect(analytics.count(AnalyticsEvent.sessionStart), 2);
  });

  test('simple events carry only their game id', () {
    events
      ..outOfEnergy()
      ..purchaseStarted('pearls_tier1')
      ..letterOpened('letter_01');
    expect(analytics.names, [
      AnalyticsEvent.outOfEnergy,
      AnalyticsEvent.purchaseStarted,
      AnalyticsEvent.letterOpened,
    ]);
    expect(
      [for (final e in analytics.events) e.$2],
      [
        <String, Object>{},
        {'product_id': 'pearls_tier1'},
        {'letter_id': 'letter_01'},
      ],
    );
  });

  test('each purchase is reported once, when it is put into the game', () {
    final wallet = PurchasesController(
      products: _products,
      addManna: (_) {},
      raiseGenerators: (_) {},
    );
    final apply = events.reportingPurchases(wallet);
    final server = [_p('t1', 'pearls_tier1'), _p('t2', 'starter_pack')];
    expect(apply(server).pearls, 125);
    expect(wallet.pearls, 125);
    expect(analytics.count(AnalyticsEvent.purchaseComplete), 2);
    expect(
      {for (final e in analytics.events) e.$2['product_id']},
      {'pearls_tier1', 'starter_pack'},
    );
    // The same list again delivers nothing and reports nothing.
    expect(apply(server).isEmpty, isTrue);
    expect(analytics.count(AnalyticsEvent.purchaseComplete), 2);
  });
}
