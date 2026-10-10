// Checks content/starting_board.json and content/products.json. Pure Dart.
import 'package:whispers_of_joppa/domain/models.dart';

final _idPattern = RegExp(r'^[a-z][a-z0-9_]*$');

void checkStartingBoard(
  Map<String, dynamic> board, {
  required Set<String> generatorIds,
  required Set<String> itemIds,
  Map<String, int> generatorUnlockChapters = const {},

  /// Generators that are used up and gone: never part of the starting board
  /// (it would hand them back each time).
  Set<String> temporaryGeneratorIds = const {},
  required Map<String, dynamic> economy,
  required List<String> problems,
}) {
  final manna = board['manna'];
  final maxManna = economy['max_manna'];
  if (manna is! int || manna < 0 || (maxManna is int && manna > maxManna)) {
    problems.add('Starting board: manna must be between 0 and max_manna');
  }
  final taken = <(int, int)>{};
  final placed = <String>{};
  void checkCell(String what, Map<String, dynamic> entry) {
    final col = entry['col'];
    final row = entry['row'];
    final onBoard =
        col is int &&
        row is int &&
        col >= 0 &&
        col < BoardState.cols &&
        row >= 0 &&
        row < BoardState.rows;
    if (!onBoard) {
      problems.add('Starting board: $what is off the board ($col, $row)');
    } else if (!taken.add((col, row))) {
      problems.add('Starting board: two things share cell ($col, $row)');
    }
  }

  for (final g
      in (board['generators'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    final id = g['generator_id'];
    if (!generatorIds.contains(id)) {
      problems.add('Starting board: unknown generator "$id"');
    } else if (!placed.add(id as String)) {
      problems.add('Starting board: generator "$id" is placed more than once');
    }
    if (temporaryGeneratorIds.contains(id)) {
      problems.add(
        'Starting board: "$id" is a temporary generator and cannot start on '
        'the board',
      );
    }
    checkCell('generator $id', g);
    final chapter = g['chapter'];
    if (chapter != null && (chapter is! int || chapter < 1)) {
      problems.add('Starting board: generator "$id" chapter must be 1 or more');
    }
    final level = g['level'];
    if (level != null && (level is! int || level < 1)) {
      problems.add('Starting board: generator "$id" level must be 1 or more');
    }
    // The chapter a generator arrives in is written in two places; they
    // must agree.
    final unlock = generatorUnlockChapters[id];
    final arrives = chapter is int ? chapter : 1;
    if (unlock != null && unlock != arrives) {
      problems.add(
        'Starting board: generator "$id" arrives in chapter $arrives but '
        'generators.json unlocks it in chapter $unlock',
      );
    }
  }
  for (final i
      in (board['items'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    final id = i['item_id'];
    if (!itemIds.contains(id)) {
      problems.add('Starting board: unknown item "$id"');
    }
    checkCell('item $id', i);
  }
}

/// Adds a plain-English line to [problems] for every mistake in the products.
void checkProducts(List<Map<String, dynamic>> products, List<String> problems) {
  final ids = <String>{};
  for (final product in products) {
    final id = product['id'];
    if (id is! String || !_idPattern.hasMatch(id)) {
      problems.add('Product id "$id" must be lowercase snake_case');
    } else if (!ids.add(id)) {
      problems.add('Product id "$id" is used more than once');
    }
    final type = product['type'];
    if (type != 'consumable' && type != 'non_consumable') {
      problems.add('Product $id: type must be consumable or non_consumable');
    }
    for (final key in ['pearls', 'manna', 'generator_level']) {
      final value = product[key];
      if (value != null && (value is! int || value < 0)) {
        problems.add('Product $id: $key must be a whole number, 0 or more');
      }
    }
    final level = product['generator_level'];
    if (level is int && (level < 1 || level > 5)) {
      problems.add('Product $id: generator_level must be 1 to 5');
    }
    final gives =
        (product['pearls'] is int ? product['pearls'] as int : 0) +
        (product['manna'] is int ? product['manna'] as int : 0);
    if (gives == 0 && product['generator_level'] == null) {
      problems.add('Product $id: gives nothing');
    }
  }
}
