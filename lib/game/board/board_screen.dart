import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/features/orders/orders_bar.dart';
import 'package:whispers_of_joppa/features/story/scene_screen.dart';
import 'package:whispers_of_joppa/game/board/manna_bar.dart';
import 'package:whispers_of_joppa/game/board/board_session.dart';

/// The main game board screen — hosts the Flame merge board.
class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    this.startingMannaOverride,
    this.saveRepository,
    this.playOpeningScene = true,
  });

  /// Whether a new game begins with the opening story scene. Tests that are
  /// about the board turn this off.
  final bool playOpeningScene;

  /// Where the game is saved. Tests pass their own; the app uses the default.
  final SaveRepository? saveRepository;

  /// Lets a test begin with a chosen amount of Manna instead of the amount
  /// in content/starting_board.json. Never set in the real app.
  final int? startingMannaOverride;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  BoardSession? _session;
  bool _popupOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    // Saves any unsaved change, then stops the timers.
    _session?.dispose();
    super.dispose();
  }

  Future<void> _showOutOfManna() async {
    final manna = _session?.manna;
    if (manna == null || _popupOpen || !mounted) return;
    _popupOpen = true;
    await showOutOfMannaPopup(context, manna);
    _popupOpen = false;
  }

  Future<void> _init() async {
    try {
      final session = await BoardSession.create(
        saveRepository: widget.saveRepository ?? SaveRepository(),
        onOutOfManna: _showOutOfManna,
        startingMannaOverride: widget.startingMannaOverride,
      );
      if (!mounted) {
        await session.dispose();
        return;
      }
      setState(() => _session = session);
      final opening = session.openingScene;
      if (opening != null && widget.playOpeningScene) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SceneScreen(
              scene: opening,
              characterNames: session.characterNames,
              availableAssets: session.assetPaths,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
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
    } else if (session == null) {
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
                  WalletChips(controller: session.orders),
                  MannaBar(controller: session.manna),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: OrdersBar(
                controller: session.orders,
                items: session.game.itemCatalog,
                characterNames: session.characterNames,
                placeholderColors: session.game.chainPlaceholderColors,
              ),
            ),
            Expanded(child: GameWidget(game: session.game)),
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
