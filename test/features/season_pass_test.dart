// The season pass in play: which passes the server's records give, what a
// pass pays as the event is played. (Its pop-up: season_pass_dialog_test.)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/purchase_target.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/domain/events.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/event_controller.dart';
import 'package:whispers_of_joppa/features/events/season_pass_ledger.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

import '../support/event_fixtures.dart';

const _offers = <String, dynamic>{
  'season_pass': {
    'premium_product': 'pass_premium',
    'plus_product': 'pass_premium_plus',
  },
};
PurchaseRecord _pass(String tx, {bool plus = false, bool granted = true}) =>
    PurchaseRecord(
      transactionId: tx,
      productId: plus ? 'pass_premium_plus' : 'pass_premium',
      granted: granted,
      refunded: !granted,
      grant: PurchaseGrant(passEventId: 'boat_festival', passPlus: plus),
    );

void main() {
  final start = DateTime.utc(2026, 10, 1);
  final event = EventModel.fromJson(
    eventRow(
      startsAt: start,
      endsAt: DateTime.utc(2026, 10, 22),
      pass: testPass,
    ),
  );
  final products = seasonPassProductsFrom(_offers);
  late SaveExtras extras;
  late SeasonPassLedger ledger;
  late EventProgressRepository repository;
  late int manna;
  late int talents;
  late int pearls;
  late List<String> items;

  EventController make([EventProgress? progress]) => EventController(
    event: event,
    progress: progress ?? EventProgress(eventId: event.id),
    repository: repository,
    addManna: (n) => manna += n,
    addTalents: (n) => talents += n,
    saveGame: () async {},
    tier: () => ledger.tierFor(event.id),
    addPearls: (n) => pearls += n,
    giveItems: items.addAll,
    clock: () => start.add(const Duration(days: 1)),
  );

  setUp(() {
    extras = SaveExtras();
    ledger = SeasonPassLedger(extras);
    final dir = Directory.systemTemp.createTempSync('joppa_pass');
    repository = EventProgressRepository(directory: () async => dir);
    manna = talents = pearls = 0;
    items = [];
  });
  tearDown(() => extras.dispose());

  test('a pass purchase is read from the server\'s record', () {
    final grant = PurchaseGrant.fromJson(<String, dynamic>{
      'pearls': 0,
      'pass': {'tier': 'plus', 'event_id': 'boat_festival'},
    });
    expect(grant?.passEventId, 'boat_festival');
    expect(grant?.passPlus, isTrue);
    final odd = PurchaseGrant.fromJson(<String, dynamic>{
      'pass': {'tier': 'plus'},
    });
    expect(odd?.passEventId, isNull);
    expect(PurchaseGrant.fromJson(<String, dynamic>{})?.passEventId, isNull);
    expect(products.keys, ['pass_premium', 'pass_premium_plus']);
    expect(products['pass_premium']?.reusable, isTrue);
    expect(totalGrant([_pass('a')], products).passes, 1);
    expect(totalGrant([_pass('a')], products).isEmpty, isFalse);
    expect(describeGrant(totalGrant([_pass('a')], products)), contains('Pass'));
  });

  test('the passes held follow the server: bought, upgraded, refunded', () {
    expect(ledger.tierFor('boat_festival'), PassTier.free);
    ledger.serverRecords([_pass('a')]);
    expect(ledger.tierFor('boat_festival'), PassTier.premium);
    expect(ledger.tierFor('another'), PassTier.free);
    // The same list again writes nothing.
    var writes = 0;
    extras.addListener(() => writes++);
    ledger.serverRecords([_pass('a')]);
    expect(writes, 0);
    ledger.serverRecords([_pass('a'), _pass('b')]);
    expect(ledger.tierFor('boat_festival'), PassTier.plus);
    ledger.serverRecords([_pass('a', granted: false), _pass('b')]);
    expect(ledger.tierFor('boat_festival'), PassTier.premium);
    ledger.serverRecords([_pass('c', plus: true)]);
    expect(ledger.tierFor('boat_festival'), PassTier.plus);
    ledger.serverRecords(const []);
    expect(ledger.tierFor('boat_festival'), PassTier.free);
    // A fresh game reads them back from the save.
    ledger.serverRecords([_pass('a')]);
    expect(
      SeasonPassLedger(SaveExtras(extras.all)).tierFor('boat_festival'),
      PassTier.premium,
    );
  });

  test('the pass is shown unasked once an event, and never to its holder', () {
    expect(ledger.takeUpsell('boat_festival'), isTrue);
    expect(ledger.takeUpsell('boat_festival'), isFalse);
    // Reading the server's list does not forget that.
    ledger.serverRecords([_pass('a')]);
    ledger.serverRecords(const []);
    expect(ledger.takeUpsell('boat_festival'), isFalse);
    ledger.serverRecords([_pass('a')]);
    expect(ledger.takeUpsell('feast'), isTrue);
    final holder = SeasonPassLedger(SaveExtras())..serverRecords([_pass('a')]);
    expect(holder.takeUpsell('boat_festival'), isFalse);
  });

  test('without a pass only the free track pays', () {
    final c = make()..onMerged(5);
    expect(manna, 10);
    expect(talents, 50);
    expect(pearls, 0);
    expect(c.premiumPaid, 0);
    expect(c.justPaidPass.value, isEmpty);
    c.dispose();
  });

  test('Premium pays its reward at each milestone; bought late, it pays '
      'all those already reached, once', () {
    final c = make()..onMerged(5);
    ledger.serverRecords([_pass('a')]);
    expect(c.settle(), isTrue);
    expect(manna, 15);
    expect(pearls, 4);
    expect(c.premiumPaid, 2);
    expect(c.justPaidPass.value.length, 2);
    expect(c.settle(), isFalse);
    expect(pearls, 4);
    c.onMerged(4);
    expect(talents, 50 + 100 + 30);
    expect(items, ['thread_01']);
    expect(c.premiumPaid, 3);
    // No bonus points and no endless track on Premium.
    expect(c.points, 9);
    c.onMerged(6);
    for (var i = 0; i < 20; i++) {
      c.onMerged(6);
    }
    expect(c.endlessPaid, 0);
    c.dispose();
  });

  test('Premium Plus adds bonus points and an endless track', () async {
    ledger.serverRecords([_pass('a', plus: true)]);
    final c = make()..onMerged(4);
    // 4 earned count as 6: the first two milestones.
    expect(c.points, 6);
    expect(c.paid, 2);
    expect(c.premiumPaid, 2);
    for (var i = 0; i < 6; i++) {
      c.onMerged(6);
    }
    // 40 earned count as 60: one step of 50 past the last milestone at 9.
    expect(c.points, 60);
    expect(c.endlessPaid, 1);
    expect(talents, 50 + 100 + 30 + 7);
    c.onMerged(6);
    expect(c.endlessPaid, 1);
    // What was paid is kept with the player's progress.
    await c.save();
    final back = await repository.load(event.id);
    expect(back.premiumPaid, 3);
    expect(back.endlessPaid, 1);
    final again = make(back)..settle();
    expect(again.endlessPaid, 1);
    expect(talents, 50 + 100 + 30 + 7);
    c.dispose();
    again.dispose();
  });

  test('progress saved before the pass reads as nothing paid', () {
    final old = EventProgress.fromJson({
      'event_id': 'boat_festival',
      'points': 5,
      'paid': 2,
      'items': <dynamic>[],
    });
    expect(old.premiumPaid, 0);
    expect(old.endlessPaid, 0);
  });

  test('the next reward is told from the points that count (with the Plus '
      'bonus)', () {
    ledger.serverRecords([_pass('a', plus: true)]);
    final c = make()..onMerged(4);
    // 4 earned count as 6: the milestones at 2 and 5 are behind.
    expect(c.next?.points, 9);
    c.onMerged(2);
    expect(c.points, 9);
    expect(c.next, isNull);
    expect(c.trackFinished, isTrue);
    c.dispose();
  });

  test('a pass refunded and bought again never pays anything twice', () {
    ledger.serverRecords([_pass('a', plus: true)]);
    final c = make();
    for (var i = 0; i < 7; i++) {
      c.onMerged(6);
    }
    // 42 earned count as 63.
    expect(c.premiumPaid, 3);
    expect(c.endlessPaid, 1);
    final had = (manna, talents, pearls, items.length);
    // Refunded: the points fall back to 42; nothing is paid, nothing lost.
    ledger.serverRecords(const []);
    expect(c.settle(), isFalse);
    expect(c.points, 42);
    // Bought again: everything already paid stays paid.
    ledger.serverRecords([_pass('b', plus: true)]);
    expect(c.settle(), isFalse);
    expect((manna, talents, pearls, items.length), had);
    c.dispose();
  });
}
