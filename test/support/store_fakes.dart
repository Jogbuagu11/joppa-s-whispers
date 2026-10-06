// In-memory stand-ins for the app store and the purchase server.
import 'dart:async';

import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/services/purchase_backend.dart';
import 'package:whispers_of_joppa/services/store_service.dart';

class FakeStore implements StoreService {
  final _controller = StreamController<StorePurchase>.broadcast();
  int _next = 1;

  /// Purchases the store has been told are finished.
  final List<String> finished = [];
  final List<bool> finishedAsConsumable = [];

  /// What the next purchase attempt does.
  StorePurchaseStatus nextStatus = StorePurchaseStatus.purchased;
  bool available = true;
  bool throwOnBuy = false;
  int restores = 0;

  /// Purchases the store still holds as unfinished (redelivered on restore).
  final List<StorePurchase> unfinished = [];

  @override
  String platform = 'ios';

  @override
  Stream<StorePurchase> get purchases => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<StoreProduct>> loadProducts(Set<String> productIds) async => [
    for (final id in productIds)
      StoreProduct(id: id, title: 'Title $id', price: r'$0.99'),
  ];

  @override
  Future<void> buy(ProductModel product) async {
    if (throwOnBuy) throw Exception('store closed');
    emit(product.id, status: nextStatus);
  }

  /// Makes the store report a purchase. Returns its transaction id.
  String emit(
    String productId, {
    StorePurchaseStatus status = StorePurchaseStatus.purchased,
    String? transactionId,
  }) {
    final id = transactionId ?? 'tx${_next++}';
    final purchase = StorePurchase(
      productId: productId,
      transactionId: id,
      receipt: 'receipt-$id',
      status: status,
    );
    if (status == StorePurchaseStatus.purchased) unfinished.add(purchase);
    _controller.add(purchase);
    return id;
  }

  @override
  Future<void> finish(
    StorePurchase purchase, {
    required bool consumable,
  }) async {
    finished.add(purchase.transactionId ?? '');
    finishedAsConsumable.add(consumable);
    unfinished.removeWhere((p) => p.transactionId == purchase.transactionId);
  }

  @override
  Future<void> restore() async {
    restores++;
    for (final purchase in [...unfinished]) {
      _controller.add(purchase);
    }
  }
}

class FakePurchaseBackend implements PurchaseBackend {
  @override
  bool signedIn = true;

  /// What the server answers to the next verification.
  VerifyResult answer = VerifyResult.confirmed;

  /// When true, a confirmed purchase is recorded for a DIFFERENT player (a
  /// receipt reused on another account).
  bool recordForSomeoneElse = false;

  /// When true, reading the purchase list fails.
  bool listOffline = false;

  /// This player's purchases as the server holds them.
  final List<PurchaseRecord> recorded = [];
  final List<String> verified = [];

  @override
  Future<VerifyResult> verify({
    required String platform,
    required String productId,
    required String transactionId,
    required String receipt,
  }) async {
    verified.add(transactionId);
    if (answer == VerifyResult.confirmed &&
        !recordForSomeoneElse &&
        !recorded.any((r) => r.transactionId == transactionId)) {
      recorded.add(
        PurchaseRecord(
          transactionId: transactionId,
          productId: productId,
          granted: true,
        ),
      );
    }
    return answer;
  }

  @override
  Future<List<PurchaseRecord>> myPurchases() async {
    if (listOffline) throw Exception('offline');
    return [...recorded];
  }
}
