import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';

/// The main game board screen — hosts the Flame merge board.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  BoardGame? _game;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final loader = ContentLoader();
      await loader.load();

      // The opening board comes from content/starting_board.json.
      final start = loader.startingBoard;
      final generatorPlacements = <GeneratorPlacement>[];
      for (final g in start.generators) {
        final gen = loader.generators[g.generatorId];
        if (gen == null) {
          throw StateError(
            'Unknown generator in starting board: ${g.generatorId}',
          );
        }
        generatorPlacements.add((gen: gen, col: g.col, row: g.row));
      }
      final startingItems = <ItemPlacement>[];
      for (final i in start.items) {
        final item = loader.items[i.itemId];
        if (item == null) {
          throw StateError('Unknown item in starting board: ${i.itemId}');
        }
        startingItems.add((item: item, col: i.col, row: i.row));
      }

      final game = BoardGame(
        itemCatalog: loader.items,
        chainData: loader.chains,
        generatorLevels: loader.generatorLevels,
        generatorPlacements: generatorPlacements,
        startingItems: startingItems,
        chainPlaceholderColors: loader.chainPlaceholderColors,
        initialManna: start.manna,
      );

      setState(() {
        _game = game;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final error = _error;
    final Widget body;
    if (error != null) {
      body = Center(
        child: Text(
          error,
          key: const Key('board_error'),
          style: const TextStyle(color: Colors.red),
        ),
      );
    } else if (_loading || game == null) {
      body = const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4802A)),
      );
    } else {
      body = Stack(
        children: [
          GameWidget(game: game),
          _MannaOverlay(game: game),
        ],
      );
    }
    return Scaffold(
      key: const Key('board_screen'),
      backgroundColor: const Color(0xFF1A1205),
      body: body,
    );
  }
}

/// Simple manna counter overlay — replaced by full bar in Milestone 6.
class _MannaOverlay extends StatelessWidget {
  const _MannaOverlay({required this.game});

  final BoardGame game;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ValueListenableBuilder<int>(
          valueListenable: game.mannaNotifier,
          builder: (ctx, manna, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1205).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4802A)),
              ),
              child: Text(
                'Manna: $manna',
                style: const TextStyle(
                  color: Color(0xFFD4802A),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
