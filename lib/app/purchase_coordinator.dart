// Runs a purchase from the store's payment sheet to Pearls in the game.
//
// The rule that matters: nothing is granted because the store on the phone
// says so. A purchase is sent to the server; only purchases the server has
// recorded for this player are put into the game, each exactly once; the game
// is saved; and only then is the store told the purchase is finished.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/services/purchase_backend.dart';
import 'package:whispers_of_joppa/services/store_service.dart';

final _log = Logger('Purchases');

/// The game a purchase is delivered into.
class PurchaseTarget {
  /// Puts server-confirmed purchases into the game (each once) and returns
  /// what was added.
  final GrantTotals Function(List<PurchaseRecord> fromServer) applyConfirmed;

  /// Whether a transaction's contents are already in the game.
  final bool Function(String transactionId) hasApplied;

  /// Writes the game to disk now, so a grant survives the app being closed.
  final Future<void> Function() saveNow;

  const PurchaseTarget({
    required this.applyConfirmed,
    required this.hasApplied,
    required this.saveNow,
  });
}

class PurchaseCoordinator {
  final StoreService store;
  final PurchaseBackend backend;

  /// product_id -> what it gives (from content/products.json). Set again
  /// whenever a game session loads its content.
  Map<String, ProductModel> products;

  /// The running game, or null while none is attached (purchases then wait).
  PurchaseTarget? target;

  /// A line to show the player about the purchase they just made, or null.
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);

  /// True while a purchase is being checked.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  StreamSubscription<StorePurchase>? _subscription;

  // Purchases the store has reported but that could not be delivered yet
  // (no connection, signed out, no game attached). Retried by [resume].
  final Map<String, StorePurchase> _waiting = {};

  // Products the player tapped Buy for in this run: only these get messages,
  // so purchases the store re-sends by itself stay silent.
  final Set<String> _asked = {};

  // Deliveries run one at a time.
  Future<void> _queue = Future<void>.value();

  PurchaseCoordinator({
    required this.store,
    required this.backend,
    this.products = const {},
  });

  /// Starts listening to the store. Purchases left unfinished by an earlier
  /// run arrive here too and are delivered.
  void start() {
    _subscription ??= store.purchases.listen(
      (purchase) => _queue = _queue.then((_) => _handle(purchase)),
      onError: (Object e) => _log.warning('Store stream error: $e'),
    );
  }

  /// The store's listing (with its own prices) for the game's products.
  Future<List<StoreProduct>> loadProducts() async {
    try {
      if (!await store.isAvailable()) return const [];
      return await store.loadProducts(products.keys.toSet());
    } on Exception catch (e) {
      _log.warning('Could not load products from the store: $e');
      return const [];
    }
  }

  /// Opens the store's payment sheet for [productId].
  Future<void> buy(String productId) async {
    final product = products[productId];
    if (product == null || busy.value) return;
    final accountId = backend.userId;
    if (accountId == null) {
      message.value = 'Sign in first, so your purchase is kept safe.';
      return;
    }
    message.value = null;
    _asked.add(productId);
    try {
      await store.buy(product, accountId: accountId);
    } on Object catch (e) {
      // Includes store plugin errors that are not Exceptions.
      _log.warning('Could not start the purchase: $e');
      message.value = 'The store could not be opened. Please try again.';
    }
  }

  /// Checks with the server for purchases that belong to this player but are
  /// not in the game yet (an interrupted purchase, a new phone) and adds
  /// them. Safe to call at any time. Returns what was added.
  Future<GrantTotals> deliverConfirmed() async {
    final game = target;
    if (game == null || !backend.signedIn) return const GrantTotals();
    try {
      final added = game.applyConfirmed(await backend.myPurchases());
      if (!added.isEmpty) await game.saveNow();
      return added;
    } on Exception catch (e) {
      _log.warning('Could not read purchases from the server: $e');
      return const GrantTotals();
    }
  }

  /// Run at launch and when the app comes back: retries purchases that could
  /// not be delivered earlier, quietly asks the store for unfinished ones,
  /// and delivers anything the server holds for this player. Never prompts.
  Future<void> resume() async {
    for (final purchase in [..._waiting.values]) {
      _queue = _queue.then((_) => _verifyAndDeliver(purchase));
    }
    await _queue;
    try {
      await store.redeliverUnfinished();
    } on Exception catch (e) {
      _log.warning('Could not check for unfinished purchases: $e');
    }
    await deliverConfirmed();
  }

  /// The "Restore purchases" button: asks the store to report purchases
  /// again and delivers anything owed.
  Future<void> restore() async {
    try {
      await store.restore();
    } on Exception catch (e) {
      _log.warning('Restore failed: $e');
    }
    final added = await deliverConfirmed();
    message.value = added.isEmpty
        ? 'Nothing new to restore.'
        : '${_describe(added)} restored.';
  }

  /// Stops delivering into a game that is being closed or replaced.
  void detach() => target = null;

  void _say(StorePurchase purchase, String? text) {
    if (_asked.contains(purchase.productId)) message.value = text;
  }

  Future<void> _handle(StorePurchase purchase) async {
    switch (purchase.status) {
      case StorePurchaseStatus.pending:
        _say(purchase, 'Waiting for the store to confirm your payment…');
      case StorePurchaseStatus.canceled:
        // The player changed their mind: nothing granted, nothing to say.
        _say(purchase, null);
      case StorePurchaseStatus.failed:
        _say(
          purchase,
          'The purchase did not go through. You were not charged.',
        );
      case StorePurchaseStatus.purchased || StorePurchaseStatus.restored:
        await _verifyAndDeliver(purchase);
    }
  }

  Future<void> _verifyAndDeliver(StorePurchase purchase) async {
    final transactionId = purchase.transactionId;
    final product = products[purchase.productId];
    if (transactionId == null || transactionId.isEmpty || product == null) {
      _log.warning(
        'Ignoring purchase without id or product: ${purchase.productId}',
      );
      return;
    }
    final game = target;
    if (game == null || !backend.signedIn) {
      // Kept unfinished and retried later.
      _waiting[transactionId] = purchase;
      _say(purchase, 'Sign in to receive your purchase.');
      return;
    }
    if (game.hasApplied(transactionId)) {
      // Already in the game (the store re-sends owned one-time products):
      // no server call needed, just make sure the store knows it is done.
      _waiting.remove(transactionId);
      await _finish(purchase, product);
      return;
    }
    busy.value = true;
    try {
      final result = await backend.verify(
        platform: store.platform,
        productId: purchase.productId,
        transactionId: transactionId,
        receipt: purchase.receipt,
      );
      switch (result) {
        case VerifyResult.rejected:
          // Grant nothing and leave it unfinished, as the spec requires.
          _waiting.remove(transactionId);
          _say(purchase, "Purchase couldn't be verified.");
          return;
        case VerifyResult.unavailable:
          _waiting[transactionId] = purchase;
          _say(
            purchase,
            "We couldn't check your purchase just now. It will be "
            'delivered automatically when you are back online.',
          );
          return;
        case VerifyResult.confirmed:
          break;
      }
      // Grant from what the server has recorded for THIS player, never from
      // the store's word or the server's reply alone.
      final List<PurchaseRecord> recorded;
      try {
        recorded = await backend.myPurchases();
      } on Exception catch (e) {
        _log.warning('Could not read purchases after verifying: $e');
        _waiting[transactionId] = purchase;
        _say(purchase, 'Your purchase is confirmed and will appear shortly.');
        return;
      }
      if (!recorded.any((r) => r.transactionId == transactionId && r.granted)) {
        // Confirmed, but not recorded for this player (for example a receipt
        // already used on another account). Nothing is granted.
        _log.warning(
          'Transaction $transactionId is not recorded for this player',
        );
        _waiting.remove(transactionId);
        _say(purchase, "Purchase couldn't be verified.");
        return;
      }
      final added = game.applyConfirmed(recorded);
      // The grant is written to disk before the store is told it is done, so
      // closing the app at this moment cannot lose it.
      await game.saveNow();
      _waiting.remove(transactionId);
      _say(
        purchase,
        added.isEmpty
            ? 'Your purchase is already in your game.'
            : 'Thank you! ${_describe(added)} added.',
      );
      await _finish(purchase, product);
    } on Exception catch (e, stack) {
      _log.severe('Purchase delivery failed', e, stack);
      _waiting[transactionId] = purchase;
      _say(
        purchase,
        'Something went wrong delivering your purchase. It will be '
        'delivered automatically next time you open the game.',
      );
    } finally {
      busy.value = false;
    }
  }

  /// Tells the store the purchase is delivered. A store that fails or never
  /// answers must not hold up the game: it will report the purchase again.
  Future<void> _finish(StorePurchase purchase, ProductModel product) async {
    try {
      await store
          .finish(purchase, consumable: product.consumable)
          .timeout(const Duration(seconds: 15));
    } on Object catch (e) {
      _log.warning(
        'The store did not confirm finishing ${purchase.productId}: $e',
      );
    }
  }

  String _describe(GrantTotals t) => [
    if (t.pearls > 0) '${t.pearls} Pearls',
    if (t.manna > 0) '${t.manna} Manna',
    if (t.generatorLevel != null) 'a level-${t.generatorLevel} generator',
  ].join(', ');

  Future<void> dispose() async {
    await _subscription?.cancel();
    message.dispose();
    busy.dispose();
  }
}
