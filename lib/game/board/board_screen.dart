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

      // Chapter 1 generators: Grandma's Pantry and Tree of Life.
      // Placed at bottom row (row 8), cols 2 and 4.
      final genPantry = loader.generators['gen_pantry']!;
      final genTree = loader.generators['gen_tree']!;

      final game = BoardGame(
        itemCatalog: loader.items,
        chainData: loader.chains,
        generatorLevels: loader.generatorLevels,
        generatorPlacements: [
          (gen: genPantry, col: 2, row: 8),
          (gen: genTree, col: 4, row: 8),
        ],
        initialManna: 10,
      );

      // Starter items for testing (removed once Chapter 1 tutorial is built).
      game.placeItem(loader.items['bakery_01']!);
      game.placeItem(loader.items['bakery_01']!);
      game.placeItem(loader.items['fruit_01']!);

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
    return Scaffold(
      key: const Key('board_screen'),
      backgroundColor: const Color(0xFF1A1205),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4802A)),
            )
          : _error != null
          ? Center(
              child: Text(
                _error!,
                key: const Key('board_error'),
                style: const TextStyle(color: Colors.red),
              ),
            )
          : Stack(
              children: [
                GameWidget(game: _game!),
                _MannaOverlay(game: _game!),
              ],
            ),
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
