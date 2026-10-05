// Naming rules for art files. Pure Dart so tool/process_assets.dart can use it.

final _itemName = RegExp(r'^item_[a-z]+_\d{2}$');

/// Turns a raw art file name into its clean item name, or null if it does not
/// follow `item_<chain>_<two-digit tier>`. Extra endings such as ".png.jpeg"
/// or "..jpeg" are ignored.
String? itemAssetBaseName(String fileName) {
  final dot = fileName.indexOf('.');
  final base = (dot < 0 ? fileName : fileName.substring(0, dot)).toLowerCase();
  return _itemName.hasMatch(base) ? base : null;
}

/// The art file name an item is expected to have, e.g. bakery_04 in chain
/// bakery -> item_bakery_04.
String expectedItemAssetBaseName(String chainId, int tier) =>
    'item_${chainId}_${tier.toString().padLeft(2, '0')}';

/// Item ids in [chainsJson] that have no art among [availableBaseNames].
List<String> itemsMissingArt(
  List<dynamic> chainsJson,
  Set<String> availableBaseNames,
) {
  final missing = <String>[];
  for (final c in chainsJson) {
    final chain = c as Map<String, dynamic>;
    for (final t in chain['tiers'] as List<dynamic>) {
      final tier = t as Map<String, dynamic>;
      final expected = expectedItemAssetBaseName(
        chain['id'] as String,
        tier['tier'] as int,
      );
      if (!availableBaseNames.contains(expected)) {
        missing.add(tier['item_id'] as String);
      }
    }
  }
  return missing;
}
