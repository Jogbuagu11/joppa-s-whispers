// Loading the pictures for items and generators.
part of 'board_game.dart';

extension BoardArt on BoardGame {
  /// Loads the picture for every item that names one. An item whose picture
  /// is missing or unreadable keeps its coloured placeholder. BoardScreen
  /// calls this before showing the board so the first frame already has art.
  Future<void> loadArt() async {
    images.prefix = '';
    // Only pictures that are really in the app are asked for: asking for a
    // missing one raises an error even when it is caught.
    final have = (await AssetManifest.loadFromAssetBundle(
      rootBundle,
    )).listAssets().toSet();
    await Future.wait([
      for (final item in itemCatalog.values)
        if (have.contains(item.asset)) _loadArtFor(item),
      _loadGeneratorArt(have),
    ]);
  }

  Future<void> _loadArtFor(ItemModel item) async {
    try {
      _art[item.itemId] = await images.load(item.asset);
    } on Object catch (e) {
      _log.warning('No art for ${item.itemId} at ${item.asset}: $e');
    }
  }

  /// Loads the picture for every level of every generator that has one
  /// among [have] (the pictures in the app). A generator without art keeps
  /// its plain tile.
  Future<void> _loadGeneratorArt(Set<String> have) => Future.wait([
    for (final entry in generatorLevels.entries)
      for (final level in entry.value)
        if (have.contains(generatorArtPath(entry.key, level.level)))
          () async {
            final key = '${entry.key}_l${level.level}';
            try {
              _generatorArt[key] = await images.load(
                generatorArtPath(entry.key, level.level),
              );
            } on Object catch (e) {
              _log.warning('Generator picture $key could not be read: $e');
            }
          }(),
  ]);

  /// The picture for a generator at the level it has now. If that level has
  /// no picture, the nearest lower level's is used.
  ui.Image? _generatorArtFor(String generatorId) {
    final level = generatorPlacements
        .where((p) => p.gen.generatorId == generatorId)
        .firstOrNull
        ?.gen
        .level;
    for (int l = level ?? 1; l >= 1; l--) {
      final picture = _generatorArt['${generatorId}_l$l'];
      if (picture != null) return picture;
    }
    return null;
  }
}
