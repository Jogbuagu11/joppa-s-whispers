// The server side of purchases: it alone decides whether a purchase is real.
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';

final _log = Logger('PurchaseBackend');

/// What the server said about one purchase.
enum VerifyResult {
  /// The server confirmed it with the store (now or earlier).
  confirmed,

  /// The store does not recognise it. Nothing may be granted.
  rejected,

  /// The server could not be reached or failed; try again later.
  unavailable,
}

abstract mixin class PurchaseBackend {
  /// The signed-in player's id, or null. Purchases belong to an account.
  String? get userId;

  bool get signedIn => userId != null;

  /// Asks the server to check a purchase with the store and record it.
  Future<VerifyResult> verify({
    required String platform,
    required String productId,
    required String transactionId,
    required String receipt,
    String? offerId,
  });

  /// Tells the server an offer was shown to this player (so a payment for
  /// it can be matched to it even if the app is closed mid-purchase), or
  /// turned down. Never throws: it is a note, not part of the purchase.
  Future<void> noteOffer({
    required String offerId,
    required String productId,
    required String outcome,
  }) async {}

  /// Every purchase the server has recorded for this player. Throws if the
  /// server cannot be reached.
  Future<List<PurchaseRecord>> myPurchases();
}

class SupabasePurchaseBackend implements PurchaseBackend {
  final SupabaseClient _client;

  SupabasePurchaseBackend(this._client);

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  bool get signedIn => userId != null;

  @override
  Future<VerifyResult> verify({
    required String platform,
    required String productId,
    required String transactionId,
    required String receipt,
    String? offerId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'verify-purchase',
        body: {
          'platform': platform,
          'product_id': productId,
          'transaction_id': transactionId,
          'receipt_data': receipt,
          'offer_id': ?offerId,
        },
      );
      final data = response.data;
      return data is Map && data['success'] == true
          ? VerifyResult.confirmed
          : VerifyResult.rejected;
    } on FunctionException catch (e) {
      _log.warning('verify-purchase returned ${e.status}: ${e.details}');
      // 400 is the server saying the store did not confirm the purchase.
      return e.status == 400 ? VerifyResult.rejected : VerifyResult.unavailable;
    } on Exception catch (e) {
      _log.warning('verify-purchase could not be reached: $e');
      return VerifyResult.unavailable;
    }
  }

  @override
  Future<void> noteOffer({
    required String offerId,
    required String productId,
    required String outcome,
  }) async {
    final user = userId;
    if (user == null) return;
    try {
      await _client.from('offer_impressions').insert({
        'user_id': user,
        'offer_id': offerId,
        'product_id': productId,
        'outcome': outcome,
      });
    } on Exception catch (e) {
      _log.info('Could not note offer $offerId as $outcome: $e');
    }
  }

  @override
  Future<List<PurchaseRecord>> myPurchases() async {
    final rows = await _client
        .from('purchases')
        .select('transaction_id, product_id, status, grant_contents')
        .order('created_at');
    return [
      for (final row in rows)
        PurchaseRecord(
          transactionId: row['transaction_id'] as String,
          productId: row['product_id'] as String,
          granted: row['status'] == 'granted',
          refunded: row['status'] == 'refunded',
          grant: PurchaseGrant.fromJson(row['grant_contents']),
        ),
    ];
  }
}
