// The game that purchases are delivered into, as the purchase coordinator
// sees it.
import 'package:whispers_of_joppa/domain/purchases.dart';

/// The game a purchase is delivered into.
class PurchaseTarget {
  /// Puts server-confirmed purchases into the game (each once) and returns
  /// what was added.
  final GrantTotals Function(List<PurchaseRecord> fromServer) applyConfirmed;

  /// Whether a transaction's contents are already in the game.
  final bool Function(String transactionId) hasApplied;

  /// Takes back what refunded purchases gave (each once) and returns how
  /// many refunds were handled.
  final int Function(List<PurchaseRecord> fromServer) applyRefunds;

  /// Writes the game to disk now, so a grant survives the app being closed.
  final Future<void> Function() saveNow;

  const PurchaseTarget({
    required this.applyConfirmed,
    required this.hasApplied,
    required this.applyRefunds,
    required this.saveNow,
  });
}
