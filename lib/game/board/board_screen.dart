import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/features/orders/orders_bar.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/manna_bar.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

/// The main game board screen — hosts the Flame merge board.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key, this.startingMannaOverride});

  /// Lets a test begin with a chosen amount of Manna instead of the amount
  /// in content/starting_board.json. Never set in the real app.
  final int? startingMannaOverride;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  BoardGame? _game;
  MannaController? _manna;
  OrdersController? _orders;
  Map<String, String> _characterNames = const {};
  bool _popupOpen = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _orders?.dispose();
    _manna?.dispose();
    super.dispose();
  }

  Future<void> _showOutOfManna() async {
    final manna = _manna;
    if (manna == null || _popupOpen || !mounted) return;
    _popupOpen = true;
    await showOutOfMannaPopup(context, manna);
    _popupOpen = false;
  }

  Future<void> _init() async {
    try {
      final loader = ContentLoader();
      await loader.load();
      if (!mounted) return;

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

      final manna = MannaController(
        config: loader.economy,
        startingManna: widget.startingMannaOverride ?? start.manna,
      )..start();
      _manna = manna;

      final game = BoardGame(
        itemCatalog: loader.items,
        chainData: loader.chains,
        generatorLevels: loader.generatorLevels,
        generatorPlacements: generatorPlacements,
        startingItems: startingItems,
        chainPlaceholderColors: loader.chainPlaceholderColors,
        manna: manna,
        onOutOfManna: _showOutOfManna,
      );

      _orders = OrdersController(
        config: loader.economy,
        board: game,
        orders: loader.orders,
      );
      _characterNames = loader.characterNames;

      await game.loadArt();
      if (!mounted) return;

      setState(() {
        _game = game;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final manna = _manna;
    final orders = _orders;
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
    } else if (_loading || game == null || manna == null || orders == null) {
      body = const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4802A)),
      );
    } else {
      body = SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  WalletChips(controller: orders),
                  MannaBar(controller: manna),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: OrdersBar(
                controller: orders,
                items: game.itemCatalog,
                characterNames: _characterNames,
                placeholderColors: game.chainPlaceholderColors,
              ),
            ),
            Expanded(child: GameWidget(game: game)),
          ],
        ),
      );
    }
    return Scaffold(
      key: const Key('board_screen'),
      backgroundColor: const Color(0xFF1A1205),
      body: body,
    );
  }
}
