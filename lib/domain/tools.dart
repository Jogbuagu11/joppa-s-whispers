// The splitting knife and the Golden Thread (EXPANSION 20.3). Pure Dart.
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';

/// What dropping a tool on an item does.
class ToolResult {
  /// The item the target becomes.
  final String targetBecomes;

  /// The item left where the tool was (a knife leaves the second half
  /// there); null if the tool's cell is simply emptied.
  final String? toolCellBecomes;

  const ToolResult({required this.targetBecomes, this.toolCellBecomes});
}

/// The result of dropping [tool] on [target], or null if it does nothing
/// there (and so is not used up):
/// - a knife needs an item above the first tier, and makes two of the tier
///   below, one in each of the two cells;
/// - a wildcard needs an item below the top of its chain, and raises it one
///   tier;
/// - neither works on another tool.
ToolResult? resolveTool(
  ItemModel tool,
  ItemModel target,
  Map<String, ChainTierData> chains,
) {
  final use = tool.use;
  if (use == null || !use.isTool) return null;
  if (target.use?.isTool ?? false) return null;
  if (use.split) {
    if (target.tier < 2) return null;
    final lower = resolveSpawnedItemId(target.chainId, target.tier - 1, chains);
    if (lower == null) return null;
    return ToolResult(targetBecomes: lower, toolCellBecomes: lower);
  }
  final higher = resolveSpawnedItemId(target.chainId, target.tier + 1, chains);
  if (higher == null) return null;
  return ToolResult(targetBecomes: higher);
}
