// The board screen's layout under the top row (the swipeable row of cards
// and the board), and the new player's spotlight.
part of 'board_screen.dart';

mixin _BoardLayout on _BoardItems, _BoardEvents, _BoardBubbles {
  Future<void> _doNextTask();

  Widget _playArea(BoardSession session) {
    return // The board comes first: it is as wide as the screen whenever
    // the height allows, and the order cards take what is left
    // (within their limits).
    Expanded(
      child: LayoutBuilder(
        builder: (context, box) {
          final (:cards, :board) = shareHeight(
            width: box.maxWidth,
            height: box.maxHeight,
          );
          // On a very short screen the cards keep their least size
          // and anything that does not fit is cut off, not an error.
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: box.maxHeight > cards + 6 ? box.maxHeight : cards + 6,
              child: Column(
                children: [
                  _ordersBackdrop(
                    child: ListenableBuilder(
                      listenable: session.tutorial,
                      builder: (context, _) => BoardStrip(
                        story: session.story,
                        onDoTask: _doNextTask,
                        onOpenLocation: _openLocation,
                        onOpenLetters: _openLetters,
                        // No event offers during the tutorial, nor for a game played
                        // from memory only (older content): rewards could not be kept.
                        onOpenEvent:
                            _event != null &&
                                session.tutorial.isOver &&
                                !session.downgraded
                            ? _openEvent
                            : null,
                        eventLabel: _event?.name,
                        storyPicture: _storyPicture,
                        onMoved: () => _stripMoved.value++,
                        ordersChanged: session.orders,
                        readyOrders: () => session.orders.activeOrders
                            .where(session.orders.canDeliver)
                            .length,
                        // The backdrop's own edging is part of the share.
                        height: cards - 10,
                        orders: OrdersBar(
                          controller: session.orders,
                          items: session.game.itemCatalog,
                          characterNames: session.characterNames,
                          placeholderColors:
                              session.game.chainPlaceholderColors,
                          looks: _characterLooks,
                          height: cards - 10,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // The board keeps the game's dark wood behind it.
                  ColoredBox(
                    key: _boardKey,
                    color: GamePalette.background,
                    child: SizedBox(
                      height: board,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GameWidget(game: session.game),
                          ),
                          Positioned.fill(child: _bubbleLayer(session)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// What a new player should touch next, lit up through a dim veil: the
  /// two items to merge, the generator, the order to deliver, or the story
  /// card. Nothing once the tutorial is over.
  Widget _spotlight(BoardSession session) => TutorialSpotlight(
    relayout: Listenable.merge([
      session.tutorial,
      session.orders,
      session.game.boardChanged,
      _stripMoved,
    ]),
    targets: () => _spotlightTargets(session),
    alwaysLit: () => [?_rectOf(const Key('tutorial_banner'))],
    // While anything is open over the board (a scene, a message) the veil
    // stays away.
    enabled: () =>
        !_busy && !_popupOpen && (ModalRoute.of(context)?.isCurrent ?? true),
  );

  SpotlightTargets _spotlightTargets(BoardSession session) {
    final step = session.tutorial.current;
    if (step == null) return const SpotlightTargets([]);
    final board = _boardKey.currentContext?.findRenderObject();
    if (board is! RenderBox || !board.hasSize) {
      return const SpotlightTargets([]);
    }
    Rect onScreen(Rect inBoard) =>
        inBoard.shift(board.localToGlobal(Offset.zero));
    final game = session.game;
    switch (step.trigger) {
      case TutorialTrigger.merge:
        final pair = game.mergeablePair();
        if (pair == null) return const SpotlightTargets([]);
        return SpotlightTargets([
          onScreen(game.cellRect(pair.$1.$1, pair.$1.$2)),
          onScreen(game.cellRect(pair.$2.$1, pair.$2.$2)),
        ], drag: true);
      case TutorialTrigger.generatorTap:
        // The hint is about the first generator a new game has.
        final first = game.generatorPlacements.firstOrNull;
        if (first == null) return const SpotlightTargets([]);
        return SpotlightTargets([
          onScreen(game.cellRect(first.col, first.row)),
        ]);
      case TutorialTrigger.orderDelivered:
        return SpotlightTargets([?_rectOf(Key('order_card_${step.targetId}'))]);
      case TutorialTrigger.taskDone:
        return SpotlightTargets([?_rectOf(const Key('task_bar'))]);
      case TutorialTrigger.tap:
        return const SpotlightTargets([]);
    }
  }

  /// Where the widget with [key] is on the screen, or null if it is not
  /// there (or is slid out of view).
  Rect? _rectOf(Key key) {
    RenderBox? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget.key == key) {
        final box = element.findRenderObject();
        if (box is RenderBox && box.hasSize) found = box;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    final box = found;
    if (box == null) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    // Mostly off the side (the row has slid away): nothing to light up.
    final seen = rect.intersect(screen);
    return seen.width < rect.width * 0.6 || seen.height <= 0 ? null : rect;
  }
}
