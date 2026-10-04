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
      final game = BoardGame(
        itemCatalog: loader.items,
        chainData: loader.chains,
      );
      // Place starter items for testing.
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4802A)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : GameWidget(game: _game!),
    );
  }
}
