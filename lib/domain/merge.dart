// Merge logic — pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/models.dart';

/// Result of a merge attempt.
enum MergeResult { success, notMatching, noNextTier, boardFull }

/// Chain tier data loaded from content/chains.json.
class ChainTierData {
  final String chainId;
  final int maxTier;

  // Maps item_id -> tier number
  final Map<String, int> itemTiers;

  // Maps (chainId, tier) -> item_id for the merged result
  final Map<String, String> tierToItemId;

  const ChainTierData({
    required this.chainId,
    required this.maxTier,
    required this.itemTiers,
    required this.tierToItemId,
  });
}

/// Determines whether two cells can merge and what the result would be.
/// Pure function — no side effects.
MergeResult canMerge(
  ItemModel a,
  ItemModel b,
  Map<String, ChainTierData> chains,
) {
  if (a.itemId != b.itemId) return MergeResult.notMatching;
  final chain = chains[a.chainId];
  if (chain == null) return MergeResult.notMatching;
  final nextTier = a.tier + 1;
  if (nextTier > chain.maxTier) return MergeResult.noNextTier;
  return MergeResult.success;
}

/// Returns the item_id of the merged result for two identical items.
/// Caller must have already confirmed canMerge == success.
String mergedItemId(ItemModel item, Map<String, ChainTierData> chains) {
  final chain = chains[item.chainId]!; // safe: canMerge already verified
  final key = '${item.chainId}_${item.tier + 1}';
  return chain.tierToItemId[key]!; // safe: verified above
}
