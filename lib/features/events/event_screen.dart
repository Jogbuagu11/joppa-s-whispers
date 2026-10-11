// The event board: a smaller merge board with its own chain, a points
// count and a track of rewards. It spends the player's ordinary Manna.
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_app_bar.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/events.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/event_controller.dart';
import 'package:whispers_of_joppa/features/events/event_header.dart';
import 'package:whispers_of_joppa/features/events/event_pass.dart';
import 'package:whispers_of_joppa/features/settings/comfort_controller.dart';
import 'package:whispers_of_joppa/game/board/board_feedback.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/manna_bar.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

final _log = Logger('EventScreen');

const _gold = Color(0xFFD4802A);
const _ink = Color(0xFF1A1205);

class EventScreen extends StatefulWidget {
  const EventScreen({
    super.key,
    required this.event,
    required this.economy,
    required this.manna,
    required this.addTalents,
    required this.onOutOfManna,
    required this.saveGame,
    required this.markGameChanged,
    this.repository,
    this.comfort,
    this.pass,
  });

  /// The season pass's hooks; null where there is none (tests, older
  /// content).
  final EventPass? pass;

  /// Sounds, vibration and tier numbers. Null (in tests) means none.
  final ComfortController? comfort;

  final EventModel event;
  final EconomyConfig economy;

  /// The player's own Manna: the event board spends from the same bar.
  final MannaController manna;
  final void Function(int amount) addTalents;
  final VoidCallback onOutOfManna;

  /// Writes the main game (Manna spent here, rewards paid) to the phone.
  final Future<void> Function() saveGame;

  /// Tells the main game's auto-save that something changed here (Manna is
  /// spent on this board, which the main board never sees).
  final VoidCallback markGameChanged;

  /// Where progress is kept. Tests pass their own.
  final EventProgressRepository? repository;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  EventController? _controller;
  BoardGame? _game;
  Timer? _clock;
  VoidCallback? _keep;
  VoidCallback? _quiet;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Builds the event board. If anything about the event cannot be built,
  /// the screen closes quietly: the main game is never affected.
  Future<void> _start() async {
    try {
      await _build();
    } on Object catch (e, stack) {
      _log.severe('The event could not be opened', e, stack);
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _build() async {
    final event = widget.event;
    final repository = widget.repository ?? EventProgressRepository();
    final progress = await repository.load(event.id);
    final loader = ContentLoader.forEvent(
      chain: event.chain,
      generator: event.generator,
      economy: widget.economy,
    );
    final generator = loader.generators.values.first;
    final game = BoardGame(
      itemCatalog: loader.items,
      chainData: loader.chains,
      generatorLevels: loader.generatorLevels,
      generatorPlacements: [
        (gen: generator, col: event.generatorCol, row: event.generatorRow),
      ],
      startingItems: [
        for (final i in progress.items)
          if (loader.items[i.itemId] case final item?)
            if (i.col >= 0 &&
                i.col < event.cols &&
                i.row >= 0 &&
                i.row < event.rows)
              (item: item, col: i.col, row: i.row),
      ],
      chainPlaceholderColors: loader.chainPlaceholderColors,
      manna: widget.manna,
      onOutOfManna: widget.onOutOfManna,
      gridCols: event.cols,
      gridRows: event.rows,
    );
    final controller = EventController(
      event: event,
      progress: progress,
      repository: repository,
      addManna: widget.manna.add,
      addTalents: widget.addTalents,
      saveGame: widget.saveGame,
      tier: () => widget.pass?.ledger.tierFor(event.id) ?? PassTier.free,
      addPearls: widget.pass?.earnPearls,
      giveItems: widget.pass?.giveItems,
    );
    controller.boardItems = () => [
      for (final i in game.snapshotItems())
        (itemId: i.itemId, col: i.col, row: i.row),
    ];
    game.onMerged = (item) => controller.onMerged(item.tier);
    final comfort = widget.comfort;
    if (comfort != null) {
      _quiet = attachFeedback(comfort, game, rewards: controller.justPaid);
    }
    // Every change to the board is kept, so leaving loses nothing.
    void keep() {
      widget.markGameChanged();
      controller.save();
    }

    _keep = keep;
    game.boardChanged.addListener(keep);
    controller.justPaid.addListener(_announce);
    controller.justPaidPass.addListener(_announcePass);
    await game.loadArt();
    if (!mounted) {
      _quiet?.call();
      controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _game = game;
    });
    widget.pass?.changes.addListener(_passChanged);
    // A pass delivered while this screen was closed pays what it has
    // already earned.
    _passChanged();
    // Keeps the time left fresh, and closes the board when the event ends.
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (!controller.isLive) {
        // Back to the board, closing anything open over this screen too.
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() {});
      }
    });
  }

  void _announce() {
    final paid = _controller?.justPaid.value ?? const [];
    if (paid.isEmpty || !mounted) return;
    // A reward reached without the pass: the pass is shown, once an event.
    if (_controller?.tier() == PassTier.free) unawaited(_openPass(true));
    final manna = paid.fold(0, (sum, m) => sum + m.manna);
    final talents = paid.fold(0, (sum, m) => sum + m.talents);
    final parts = [
      if (manna > 0) '+$manna Manna',
      if (talents > 0) '+$talents Talents',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('event_reward'),
        content: Text(parts.join('  ')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _announcePass() {
    final paid = _controller?.justPaidPass.value ?? const [];
    if (paid.isNotEmpty && mounted) widget.pass?.announce(context, paid);
  }

  /// A pass may just have been bought (or refunded): what it has earned so
  /// far is paid now.
  void _passChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (controller.settle()) controller.save();
  }

  Future<void> _openPass([bool unasked = false]) async {
    final controller = _controller;
    if (controller == null || widget.event.pass == null) return;
    await widget.pass?.open(
      context,
      controller,
      unasked: unasked,
      quiet: () =>
          !(_game?.isDragging ?? false) &&
          (ModalRoute.of(context)?.isCurrent ?? false),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    widget.pass?.changes.removeListener(_passChanged);
    final controller = _controller;
    final keep = _keep;
    _quiet?.call();
    if (controller != null) {
      if (keep != null) _game?.boardChanged.removeListener(keep);
      controller.justPaid.removeListener(_announce);
      controller.justPaidPass.removeListener(_announcePass);
      // The last write (the game too: Manna was spent here) finishes by
      // itself; then the controller can go.
      unawaited(
        controller.save(gameFirst: true).whenComplete(controller.dispose),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final game = _game;
    return Scaffold(
      key: const Key('event_screen'),
      backgroundColor: _ink,
      appBar: gameAppBar(Text(widget.event.name)),
      body: controller == null || game == null
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : SafeArea(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListenableBuilder(
                          listenable: controller,
                          builder: (context, _) => EventHeader(
                            controller,
                            passLabel: widget.event.pass == null
                                ? null
                                : widget.pass?.text['button'],
                            onOpenPass: _openPass,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: MannaBar(controller: widget.manna, width: 170),
                      ),
                    ],
                  ),
                  Expanded(child: GameWidget(game: game)),
                ],
              ),
            ),
    );
  }
}
