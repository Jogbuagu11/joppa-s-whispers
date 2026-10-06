// Runs a purchase from the store's payment sheet to Pearls in the game.
//
// The rule that matters: nothing is granted because the store on the phone
// says so. A purchase is sent to the server; only purchases the server has
// recorded for this player are put into the game, each exactly once; and the
// store is told the purchase is finished only after that.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/services/purchase_backend.dart';
import 'package:whispers_of_joppa/services/store_service.dart';

final _log = Logger('Purchases');

class PurchaseCoordinator {
  final StoreService store;
  final PurchaseBackend backend;

  /// product_id -> what it gives (from content/products.json). Set again
  /// whenever a game session loads its content.
  Map<String, ProductModel> products;

  /// Puts server-confirmed purchases into the game (each once) and returns
  /// what was added. Null until a game is attached.
  GrantTotals Function(List<PurchaseRecord> fromServer)? applyConfirmed;

  /// A line to show the player about the latest purchase, or null.
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);

  /// True while a purchase is being checked.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  StreamSubscription<StorePurchase>? _subscription;

  PurchaseCoordinator({
    required this.store,
    required this.backend,
    this.products = const {},
  });

  /// Starts listening to the store. Purchases left unfinished by an earlier
  /// run arrive here too and are delivered.
  void start() {
    _subscription ??= store.purchases.listen(
      _handle,
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
    if (product == null) return;
    if (!backend.signedIn) {
      message.value = 'Sign in first, so your purchase is kept safe.';
      return;
    }
    message.value = null;
    try {
      await store.buy(product);
    } on Exception catch (e) {
      _log.warning('Could not start the purchase: $e');
      message.value = 'The store could not be opened. Please try again.';
    }
  }

  /// Checks with the server for purchases that belong to this player but are
  /// not in the game yet (an interrupted purchase, a new phone) and adds
  /// them. Safe to call at any time. Returns what was added.
  Future<GrantTotals> deliverConfirmed() async {
    final apply = applyConfirmed;
    if (apply == null || !backend.signedIn) return const GrantTotals();
    try {
      return apply(await backend.myPurchases());
    } on Exception catch (e) {
      _log.warning('Could not read purchases from the server: $e');
      return const GrantTotals();
    }
  }

  /// Run at launch and when the app comes back: quietly picks up purchases
  /// left unfinished and delivers anything the server holds for this player.
  /// Never prompts the player.
  Future<void> resume() async {
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
    await deliverConfirmed();
  }

  Future<void> _handle(StorePurchase purchase) async {
    switch (purchase.status) {
      case StorePurchaseStatus.pending:
        message.value = 'Waiting for the store to confirm your payment…';
      case StorePurchaseStatus.canceled:
        // The player changed their mind: nothing granted, nothing to say.
        message.value = null;
      case StorePurchaseStatus.failed:
        message.value =
            'The purchase did not go through. You were not charged.';
      case StorePurchaseStatus.purchased || StorePurchaseStatus.restored:
        await _verifyAndDeliver(purchase);
    }
  }

  Future<void> _verifyAndDeliver(StorePurchase purchase) async {
    final transactionId = purchase.transactionId;
    final product = products[purchase.productId];
    if (transactionId == null || product == null) {
      _log.warning(
        'Ignoring purchase without id or product: ${purchase.productId}',
      );
      return;
    }
    if (!backend.signedIn || applyConfirmed == null) {
      // Kept unfinished: the store will report it again next time.
      message.value = 'Sign in to receive your purchase.';
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
          message.value = "Purchase couldn't be verified.";
          return;
        case VerifyResult.unavailable:
          message.value =
              "We couldn't check your purchase just now. It will be "
              'delivered automatically when you are back online.';
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
        message.value = 'Your purchase is confirmed and will appear shortly.';
        return;
      }
      final mine = recorded.any(
        (r) => r.transactionId == transactionId && r.granted,
      );
      if (!mine) {
        // Confirmed, but not recorded for this player (for example a receipt
        // already used on another account). Nothing is granted.
        _log.warning(
          'Transaction $transactionId is not recorded for this player',
        );
        message.value = "Purchase couldn't be verified.";
        return;
      }
      final added = applyConfirmed?.call(recorded) ?? const GrantTotals();
      // Only now, with the contents in the game, is the store told it is done.
      await store.finish(purchase, consumable: product.consumable);
      message.value = added.isEmpty
          ? 'Your purchase is already in your game.'
          : 'Thank you! ${_describe(added)} added.';
    } on Exception catch (e, stack) {
      _log.severe('Purchase delivery failed', e, stack);
      message.value =
          'Something went wrong delivering your purchase. It will be '
          'delivered automatically next time you open the game.';
    } finally {
      busy.value = false;
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
