import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/features/letters/letters_screen.dart';
import 'package:whispers_of_joppa/features/orders/orders_bar.dart';
import 'package:whispers_of_joppa/features/restoration/location_screen.dart';
import 'package:whispers_of_joppa/features/story/scene_screen.dart';
import 'package:whispers_of_joppa/features/story/chapter_ending.dart';
import 'package:whispers_of_joppa/features/story/task_bar.dart';
import 'package:whispers_of_joppa/features/story/tutorial_banner.dart';
import 'package:whispers_of_joppa/game/board/manna_bar.dart';
import 'package:whispers_of_joppa/game/board/board_session.dart';

final _log = Logger('BoardScreen');

/// The main game board screen — hosts the Flame merge board.
class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    this.startingMannaOverride,
    this.saveRepository,
    this.playOpeningScene = true,
    this.playTutorial = true,
  });

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

class _BoardScreenState extends State<BoardScreen> {
  BoardSession? _session;
  bool _popupOpen = false;
  bool _busy = false;
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

  /// Pays for the next story task, then plays its scene. While this (or any
  /// other screen opened from the task bar) is running, [_busy] is set and
  /// further taps are ignored, so one tap can never pay for two tasks or
  /// stack two screens.
  Future<void> _doNextTask() async {
    final session = _session;
    if (session == null || _busy) return;
    _busy = true;
    try {
      // The task's own chapter, read before doing it: finishing a chapter's
      // last task moves the story on to the next chapter.
      final chapter = session.story.chapter;
      final locationId = chapter?.locationId;
      final task = session.story.doNext();
      if (task == null) return;
      final scene = session.scenes[task.sceneId];
      if (scene == null || scene.lines.isEmpty) {
        _log.warning('Task ${task.id} has no scene to play (${task.sceneId})');
      } else if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SceneScreen(
              scene: scene,
              characterNames: session.characterNames,
              availableAssets: session.assetPaths,
            ),
          ),
        );
      }
      // A task that restores part of the location shows the change.
      final area = task.restoresArea;
      if (area != null) await _showLocation(locationId, justRestored: area);
      // The chapter's last task ends with its closing message.
      await _showPendingEnding();
    } finally {
      _busy = false;
    }
  }

  /// Shows the closing message of a finished chapter, once.
  Future<void> _showPendingEnding() async {
    final session = _session;
    final ending = session?.pendingEnding;
    if (session == null || ending == null || !mounted) return;
    session.markEndingSeen(ending.chapterId);
    await showChapterEnding(context, ending);
  }

  /// The location button: shows the current chapter's location.
  Future<void> _openLocation() async {
    if (_busy) return;
    _busy = true;
    try {
      await _showLocation(_session?.story.chapter?.locationId);
    } finally {
      _busy = false;
    }
  }

  /// The letters button: opens the keepsake book.
  Future<void> _openLetters() async {
    final session = _session;
    if (session == null || _busy || !mounted) return;
    _busy = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LettersScreen(
            letters: session.letters,
            foundLetterIds: session.story.foundLetterIds,
          ),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _showLocation(String? locationId, {String? justRestored}) async {
    final session = _session;
    final location = session?.locations[locationId];
    if (session == null || location == null) {
      _log.warning('No location to show for "$locationId"');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocationScreen(
          location: location,
          restoredAreaIds: session.story.restoredAreaIds,
          availableAssets: session.assetPaths,
          justRestoredAreaId: justRestored,
        ),
      ),
    );
  }

  Future<void> _init() async {
    try {
      final session = await BoardSession.create(
        saveRepository: widget.saveRepository ?? SaveRepository(),
        onOutOfManna: _showOutOfManna,
        startingMannaOverride: widget.startingMannaOverride,
        playTutorial: widget.playTutorial,
      );
      if (!mounted) {
        await session.dispose();
        return;
      }
      setState(() => _session = session);
      final opening = session.openingScene;
      if (opening != null &&
          opening.lines.isNotEmpty &&
          widget.playOpeningScene) {
        await Navigator.of(context).push(
          // No slide-in: the story is the first thing a new player sees, not
          // a glimpse of the board followed by the story.
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => SceneScreen(
              scene: opening,
              characterNames: session.characterNames,
              availableAssets: session.assetPaths,
            ),
          ),
        );
      }
      // A chapter finished earlier whose closing message was never seen.
      await _showPendingEnding();
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
