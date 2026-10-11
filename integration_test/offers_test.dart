// Milestone 30: timed offers. One is shown when the game is opened (once a
// day), says exactly what it gives, and gives it only once the server has
// recorded the payment. Uses a stand-in store, server and offers table.
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/offers.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/offer_fakes.dart';
import '../test/support/store_fakes.dart';

const _welcome = Offer(
  id: 'welcome',
  kind: 'session_start',
  productId: 'offer_099',
  title: 'Welcome gift',
  contents: PurchaseGrant(pearls: 40, manna: 50, items: ['manna_jar_01']),
  nextOfferId: 'welcome_more',
);
const _more = Offer(
  id: 'welcome_more',
  kind: 'session_start',
  productId: 'offer_099',
  title: 'A bigger gift',
  contents: PurchaseGrant(pearls: 55),
);
const _thirsty = Offer(
  id: 'thirsty',
  kind: 'out_of_manna',
  productId: 'offer_099',
  title: 'Manna for the road',
  contents: PurchaseGrant(manna: 100),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final board = find.byType(GameWidget<BoardGame>);
  final popup = find.byKey(const Key('offer_popup'));

  late FakeStore store;
  late FakePurchaseBackend backend;
  late PurchaseCoordinator shop;

  setUp(() async {
    await SaveRepository().clear();
    store = FakeStore();
    backend = FakePurchaseBackend();
    shop = PurchaseCoordinator(store: store, backend: backend);
  });
  tearDown(SaveRepository().clear);

  Future<void> open(
    WidgetTester tester,
    Key key, {
    bool tutorial = false,
    int? manna,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          key: key,
          playOpeningScene: false,
          playTutorial: tutorial,
          startingMannaOverride: manna,
          shop: shop,
          offers: FakeOffersSource([_welcome, _more, _thirsty]),
        ),
      ),
    );
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data ?? '';

  testWidgets('an offer greets the player once a day; buying it gives what '
      'the server recorded; turned down, a bigger one comes later', (
    tester,
  ) async {
    backend.offerGrants['welcome'] = const PurchaseGrant(
      pearls: 40,
      manna: 50,
      items: ['manna_jar_01'],
    );
    await open(tester, const Key('first'));
    expect(popup, findsOneWidget);
    expect(find.text('Welcome gift'), findsOneWidget);
    expect(find.text('40 Pearls'), findsOneWidget);
    expect(find.text('50 Manna'), findsOneWidget);
    expect(find.byKey(const Key('offer_gift_2')), findsOneWidget);
    expect(find.byKey(const Key('offer_countdown')), findsOneWidget);
    expect(backend.noted, ['welcome:shown']);
    expect(tester.takeException(), isNull);

    // Nothing is given for looking.
    expect(text(tester, 'pearls_count'), '0');
    await tester.tap(find.byKey(const Key('offer_buy')));
    await settle(tester);
    expect(backend.offerIds, ['welcome']);
    expect(store.finished.length, 1);
    expect(find.byKey(const Key('offer_message')), findsOneWidget);
    await tester.tap(find.byKey(const Key('offer_no_thanks')));
    await settle(tester);
    expect(popup, findsNothing);
    expect(text(tester, 'pearls_count'), '40');
    // Bought, not turned down.
    expect(backend.noted, ['welcome:shown']);

    // Opened again the same day: no second greeting.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await open(tester, const Key('second'));
    expect(popup, findsNothing);
    expect(text(tester, 'pearls_count'), '40');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('no offer in the tutorial; out of Manna, one that helps is '
      'offered after the usual choices, and can be turned down', (
    tester,
  ) async {
    await open(tester, const Key('tutorial'), tutorial: true);
    expect(popup, findsNothing);
    expect(backend.noted, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await SaveRepository().clear();

    await open(tester, const Key('thirsty'), manna: 0);
    // The greeting first; turn it down.
    expect(find.text('Welcome gift'), findsOneWidget);
    await tester.tap(find.byKey(const Key('special_close')));
    await settle(tester);
    expect(popup, findsNothing);
    expect(backend.noted, ['welcome:shown', 'welcome:dismissed']);

    // A generator tap with no Manna: the usual pop-up, then the offer.
    final game = tester.widget<GameWidget<BoardGame>>(board).game;
    final gen = game?.generatorPlacements.first;
    final cell = game?.cellRect(gen?.col ?? 0, gen?.row ?? 0) ?? Rect.zero;
    await tester.tapAt(tester.getTopLeft(board) + cell.center);
    await settle(tester);
    expect(find.byKey(const Key('out_of_manna_popup')), findsOneWidget);
    await tester.tap(find.byKey(const Key('out_of_manna_ok')));
    await settle(tester);
    expect(find.text('Manna for the road'), findsOneWidget);
    expect(find.text('100 Manna'), findsOneWidget);
    await tester.tap(find.byKey(const Key('offer_no_thanks')));
    await settle(tester);
    expect(popup, findsNothing);
    expect(backend.noted.last, 'thirsty:dismissed');
    expect(backend.verified, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
