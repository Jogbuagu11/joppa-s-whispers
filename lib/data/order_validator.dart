// Checks content/orders.json and content/characters.json. Pure Dart.

final _idPattern = RegExp(r'^[a-z][a-z0-9_]*$');
const _maxTextLength = 140;

/// Adds a plain-English line to [problems] for every mistake found.
void checkOrdersAndCharacters({
  required List<Map<String, dynamic>> orders,
  required List<Map<String, dynamic>> characters,
  required List<Map<String, dynamic>> chains,
  required Map<String, dynamic> economy,
  required List<String> problems,
}) {
  final characterIds = <String>{};
  for (final character in characters) {
    final id = character['id'];
    if (id is! String || !_idPattern.hasMatch(id)) {
      problems.add('Character id "$id" must be lowercase snake_case');
    } else if (!characterIds.add(id)) {
      problems.add('Character id "$id" is used more than once');
    }
    final name = character['name'];
    if (name is! String || name.trim().isEmpty) {
      problems.add('Character $id: missing name');
    }
  }

  // item_id -> (tier, chapter its chain unlocks in)
  final itemInfo = <String, ({int tier, int unlockChapter})>{};
  for (final chain in chains) {
    final unlock = chain['unlock_chapter'];
    for (final t in chain['tiers'] as List<dynamic>) {
      final tier = t as Map<String, dynamic>;
      itemInfo[tier['item_id'] as String] = (
        tier: tier['tier'] as int,
        unlockChapter: unlock is int ? unlock : 1,
      );
    }
  }

  final perTier = economy['order_talents_per_tier'];
  final orderIds = <String>{};
  for (final order in orders) {
    final id = order['id'];
    if (id is! String || !_idPattern.hasMatch(id)) {
      problems.add('Order id "$id" must be lowercase snake_case');
    } else if (!orderIds.add(id)) {
      problems.add('Order id "$id" is used more than once');
    }
    final chapter = order['chapter'];
    if (chapter is! int || chapter < 1) {
      problems.add('Order $id: chapter must be 1 or more');
    }
    if (!characterIds.contains(order['character_id'])) {
      problems.add('Order $id: unknown character "${order['character_id']}"');
    }
    final sceneId = order['scene_id'];
    if (sceneId != null && sceneId is! String) {
      problems.add('Order $id: scene_id must be text or left empty');
    }
    final kind = order['kind'];
    if (kind != 'literal' && kind != 'spiritual') {
      problems.add('Order $id: kind must be literal or spiritual');
    }
    final text = order['text'];
    if (text is! String || text.trim().isEmpty) {
      problems.add('Order $id: missing text');
    } else if (text.length > _maxTextLength) {
      problems.add('Order $id: text is over $_maxTextLength characters');
    }

    final items = (order['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (items.isEmpty || items.length > 3) {
      problems.add('Order $id: must ask for 1 to 3 different items');
    }
    var tierSum = 0;
    final seen = <String>{};
    for (final item in items) {
      final itemId = item['item_id'];
      final count = item['count'];
      final info = itemInfo[itemId];
      if (info == null) {
        problems.add('Order $id: unknown item "$itemId"');
        continue;
      }
      if (!seen.add(itemId as String)) {
        problems.add('Order $id: item "$itemId" is listed twice');
      }
      if (count is! int || count < 1) {
        problems.add('Order $id: count for "$itemId" must be 1 or more');
        continue;
      }
      if (chapter is int && info.unlockChapter > chapter) {
        problems.add(
          'Order $id: "$itemId" is not unlocked until chapter ${info.unlockChapter}',
        );
      }
      tierSum += info.tier * count;
    }

    final rewards = order['rewards'] as Map<String, dynamic>;
    final talents = rewards['talents'];
    if (perTier is int && talents != tierSum * perTier) {
      problems.add(
        'Order $id: talents should be ${tierSum * perTier} '
        '($perTier × item tiers), not $talents',
      );
    }
    final blessings = rewards['blessings'];
    if (blessings is! int || blessings < 1 || blessings > 3) {
      problems.add('Order $id: blessings must be 1, 2 or 3');
    }
  }
}
