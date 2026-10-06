// StoreService backed by Flutter's official in_app_purchase package.
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/services/store_service.dart';

final _log = Logger('Store');

class InAppPurchaseStore implements StoreService {
  final InAppPurchase _iap = InAppPurchase.instance;

  // product id -> the store's details, needed to start a purchase.
  final Map<String, ProductDetails> _details = {};

  @override
  String get platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Stream<StorePurchase> get purchases => _iap.purchaseStream.expand(
    (batch) => batch.map(
      (p) => StorePurchase(
        productId: p.productID,
        transactionId: p.purchaseID,
        receipt: p.verificationData.serverVerificationData,
        status: switch (p.status) {
          PurchaseStatus.pending => StorePurchaseStatus.pending,
          PurchaseStatus.purchased => StorePurchaseStatus.purchased,
          PurchaseStatus.restored => StorePurchaseStatus.restored,
          PurchaseStatus.canceled => StorePurchaseStatus.canceled,
          PurchaseStatus.error => StorePurchaseStatus.failed,
        },
        raw: p,
      ),
    ),
  );

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<StoreProduct>> loadProducts(Set<String> productIds) async {
    final response = await _iap.queryProductDetails(productIds);
    if (response.notFoundIDs.isNotEmpty) {
      _log.warning('Store does not list: ${response.notFoundIDs.join(', ')}');
    }
    for (final d in response.productDetails) {
      _details[d.id] = d;
    }
    return [
      for (final d in response.productDetails)
        StoreProduct(id: d.id, title: d.title, price: d.price),
    ];
  }

  @override
  Future<void> buy(ProductModel product, {required String accountId}) async {
    final details = _details[product.id];
    if (details == null) {
      throw StateError(
        'Product ${product.id} has not been loaded from the store',
      );
    }
    final param = PurchaseParam(
      productDetails: details,
      applicationUserName: accountId,
    );
    if (product.consumable) {
      // On Google Play the pack is NOT used up automatically: that happens
      // only after the server has confirmed it and the contents are granted
      // (see finish()). On iPhone the plugin requires auto-consume; the
      // purchase still stays unfinished there until finish() is called.
      await _iap.buyConsumable(
        purchaseParam: param,
        autoConsume: !Platform.isAndroid,
      );
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  @override
  Future<void> finish(
    StorePurchase purchase, {
    required bool consumable,
  }) async {
    final details = purchase.raw;
    if (details is! PurchaseDetails) return;
    if (consumable && Platform.isAndroid) {
      // On Google Play a pack must be consumed before it can be bought again.
      final result = await _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .consumePurchase(details);
      if (result.responseCode != BillingResponse.ok) {
        // It will be tried again the next time the store reports it.
        _log.warning(
          'Google Play did not consume the pack: ${result.responseCode}',
        );
      }
      return;
    }
    if (details.pendingCompletePurchase) {
      await _iap.completePurchase(details);
    }
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> redeliverUnfinished() async {
    // The App Store re-sends unfinished purchases by itself as soon as the
    // app listens. Google Play has to be asked, and asking is silent there.
    if (Platform.isAndroid) await _iap.restorePurchases();
  }
}
