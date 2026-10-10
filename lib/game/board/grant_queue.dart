// Gifts on their way to the board (items and temporary generators from
// level-ups and, later, other rewards). A gift that finds no free cell
// waits here, is saved with the game, and is placed as soon as there is room.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';

const _itemPrefix = 'item:';
const _generatorPrefix = 'gen:';

class GrantQueue extends ChangeNotifier {
  final BoardGame game;
  final Map<String, ItemModel> items;
  final Map<String, GeneratorModel> generators;
  final List<String> _waiting;
  bool _placing = false;

  GrantQueue({
    required this.game,
    required this.items,
    required this.generators,
    Iterable<String> waiting = const [],
  }) : _waiting = [...waiting] {
    game.boardChanged.addListener(place);
  }

  /// What is still waiting for room (written to the save file).
  List<String> get waiting => List.unmodifiable(_waiting);

  /// Hands over gifts by id. They go onto the board now if there is room,
  /// or as soon as there is.
  void give({
    Iterable<String> itemIds = const [],
    Iterable<String> generatorIds = const [],
  }) {
    final before = _waiting.length;
    _waiting
      ..addAll([for (final id in itemIds) '$_itemPrefix$id'])
      ..addAll([for (final id in generatorIds) '$_generatorPrefix$id']);
    if (_waiting.length != before) notifyListeners();
    place();
  }

  /// Puts as many waiting gifts on the board as will fit.
  void place() {
    if (_placing || _waiting.isEmpty || !game.isBuilt) return;
    _placing = true;
    var changed = false;
    try {
      for (final gift in [..._waiting]) {
        if (_place(gift)) {
          _waiting.remove(gift);
          changed = true;
        }
      }
    } finally {
      _placing = false;
    }
    if (changed) notifyListeners();
  }

  /// True if [gift] is dealt with: placed, or unknown and so dropped.
  bool _place(String gift) {
    if (gift.startsWith(_itemPrefix)) {
      final item = items[gift.substring(_itemPrefix.length)];
      if (item == null) return true;
      if (!game.hasFreeCell) return false;
      game.placeItem(item);
      return true;
    }
    if (gift.startsWith(_generatorPrefix)) {
      final gen = generators[gift.substring(_generatorPrefix.length)];
      if (gen == null) return true;
      // One of each at a time: a second waits until the first is used up.
      final onBoard = game.generatorPlacements.any(
        (p) => p.gen.generatorId == gen.generatorId,
      );
      if (onBoard) return false;
      // It arrives at the level the player's own generators have reached.
      return game.addGenerator(
        gen.atLevel(game.lowestLastingLevel),
        game.gridCols ~/ 2,
        game.gridRows ~/ 2,
      );
    }
    return true;
  }

  @override
  void dispose() {
    game.boardChanged.removeListener(place);
    super.dispose();
  }
}
