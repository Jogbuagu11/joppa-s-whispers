import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/features/letters/letters_screen.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/features/orders/orders_bar.dart';
import 'package:whispers_of_joppa/features/settings/account_screen.dart';
import 'package:whispers_of_joppa/features/restoration/location_screen.dart';
import 'package:whispers_of_joppa/features/story/scene_screen.dart';
import 'package:whispers_of_joppa/features/story/chapter_ending.dart';
import 'package:whispers_of_joppa/features/story/task_bar.dart';
import 'package:whispers_of_joppa/features/story/tutorial_banner.dart';
import 'package:whispers_of_joppa/game/board/manna_bar.dart';
import 'package:whispers_of_joppa/game/board/board_cloud.dart';
import 'package:whispers_of_joppa/game/board/board_session.dart';

part 'board_screen_actions.dart';

final _log = Logger('BoardScreen');

/// The main game board screen — hosts the Flame merge board.
class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    this.startingMannaOverride,
    this.saveRepository,
    this.playOpeningScene = true,
    this.playTutorial = true,
    this.cloud,
  });

  /// The player's account and cloud save. Null (in tests, or if the backend
  /// is not set up) hides the account button and keeps the game local.
  final BoardCloud? cloud;

  /// Whether a new game shows the tutorial hints (with free early taps).
  /// Tests that are about something else turn this off.
  final bool playTutorial;

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

class _BoardScreenState extends State<BoardScreen> with _BoardScreenActions {
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
                  if (widget.cloud != null)
                    IconButton(
                      key: const Key('account_button'),
                      onPressed: _openAccount,
                      tooltip: 'Account',
                      icon: const Icon(
                        Icons.person_outline,
                        color: Color(0xFFD4802A),
                      ),
                    ),
                  MannaBar(controller: session.manna),
                ],
              ),
            ),
            TaskBar(
              controller: session.story,
              onDo: _doNextTask,
              onOpenLocation: _openLocation,
              onOpenLetters: _openLetters,
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
            TutorialBanner(
              controller: session.tutorial,
              characterNames: session.characterNames,
              availableAssets: session.assetPaths,
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
