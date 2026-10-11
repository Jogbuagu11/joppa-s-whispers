// The board screen's part in events: finding the one that is on, the
// banner that leads to it, and opening the event board.
part of 'board_screen.dart';

mixin _BoardEvents on _BoardRoutes {
  /// The season pass's hooks for the event screen (see the treasure part
  /// of this screen); null where passes cannot be had.
  EventPass? _eventPass(BoardSession session);

  /// Looks for an event that is on now. Runs in the background; the banner
  /// appears if one is found.
  Future<void> _loadEvent() async {
    final events = widget.events;
    if (events == null) return;
    final event = currentEvent(await events.load(), DateTime.now());
    if (!mounted) return;
    _wireGoals(events.goalEvents());
    // Always the freshest copy, so a correction on the server is picked up.
    if (!_eventOpen) setState(() => _event = event);
  }

  /// The board's small wording (see the items part of this screen).
  Map<String, String> get _boardText;

  /// The goal events (played on this board) of the game in play.
  GoalEventsController? _goals;
  BoardSession? _goalsFor;

  /// Whether goal events of [kind] are open to this player: from that
  /// kind's level on, after the tutorial, not in a game played from memory.
  bool _goalOpen(BoardSession session, GoalKind kind) {
    final unlock = session.levels.config.unlock(goalKindFeatures[kind] ?? '');
    return unlock != null &&
        session.tutorial.isOver &&
        !session.downgraded &&
        session.levels.level >= unlock.level;
  }

  /// Starts goal events for the game in play (once for each game), or
  /// hands the one already started the freshest list.
  void _wireGoals(List<GoalEvent> events) {
    final session = _session;
    if (session == null) return;
    if (identical(session, _goalsFor)) return _goals?.replaceEvents(events);
    _goals?.dispose();
    _goalsFor = session;
    final goals = _goals = GoalEventsController(
      events: events,
      extras: session.extras,
      open: (kind) => _goalOpen(session, kind),
      grant: (reward) {
        if (reward.manna > 0) session.manna.add(reward.manna);
        if (reward.talents > 0) session.orders.addTalents(reward.talents);
        if (reward.pearls > 0) session.purchases.earnPearls(reward.pearls);
        if (reward.items.isNotEmpty) {
          session.grants.give(itemIds: reward.items);
        }
      },
      random: widget.luck,
    );
    final onDelivered = session.orders.onDelivered;
    session.orders.onDelivered = (id) {
      onDelivered?.call(id);
      goals.orderDelivered(session.orders.talentsFor(id));
    };
    final onMerge = session.game.onMerge;
    session.game.onMerge = () {
      onMerge?.call();
      goals.merged();
    };
    session.manna.onSpent = goals.mannaSpent;
    goals.justPaid.addListener(() => _announceGoals(session, goals));
    setState(() {});
  }

  String _itemName(BoardSession session, String id) =>
      session.game.itemCatalog[id]?.name ?? '';

  /// Says which milestone was just reached and what it gave.
  void _announceGoals(BoardSession session, GoalEventsController goals) {
    if (!mounted || !identical(session, _session)) return;
    final text = _boardText;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('goal_toast'),
          duration: const Duration(seconds: 3),
          backgroundColor: GamePalette.panel,
          content: Text(
            [
              for (final paid in goals.justPaid.value)
                (text['goal_toast'] ?? '')
                    .replaceAll('{event}', paid.event.name)
                    .replaceAll(
                      '{reward}',
                      goalRewardWords(
                        paid.reward,
                        text,
                        (id) => _itemName(session, id),
                      ),
                    ),
            ].join('\n'),
            style: const TextStyle(color: GamePalette.talents),
          ),
        ),
      );
  }

  /// The goal events' round button, shown while any is on for this player.
  Widget? _goalsButton(BoardSession session) {
    final goals = _goals;
    if (goals == null || !identical(session, _goalsFor)) return null;
    if (goals.live.isEmpty) return null;
    return StripButton(
      buttonKey: const Key('goal_events_button'),
      icon: Icons.emoji_events,
      tooltip: _boardText['goal_button'] ?? '',
      onTap: () => _openGoals(session, goals),
      lit: true,
    );
  }

  Future<void> _openGoals(
    BoardSession session,
    GoalEventsController goals,
  ) async {
    if (_busy || _syncing || _popupOpen || !mounted) return;
    _popupOpen = true;
    try {
      await showGoalEvents(
        context,
        controller: goals,
        text: _boardText,
        itemName: (id) => _itemName(session, id),
      );
    } finally {
      _popupOpen = false;
    }
  }

  /// The event banner: opens the event board.
  Future<void> _openEvent() async {
    final session = _session;
    final event = _event;
    // Not while the account's game is being compared: the game under the
    // event could be swapped for another.
    if (session == null || event == null || _busy || _syncing || !mounted) {
      return;
    }
    if (!isEventLive(event, DateTime.now())) {
      setState(() => _event = null);
      return;
    }
    _busy = true;
    _eventOpen = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EventScreen(
            event: event,
            economy: session.manna.config,
            manna: session.manna,
            addTalents: session.orders.addTalents,
            onOutOfManna: _showOutOfMannaOverEvent,
            saveGame: session.saver.saveNow,
            markGameChanged: session.saver.markChanged,
            repository: widget.eventProgress,
            comfort: widget.comfort,
            pass: _eventPass(session),
          ),
        ),
      );
    } finally {
      _busy = false;
      _eventOpen = false;
    }
    // It may have ended while it was open.
    if (mounted && !isEventLive(event, DateTime.now())) {
      setState(() => _event = null);
    }
  }

  Future<void> _showOutOfMannaOverEvent() async {
    final session = _session;
    if (session == null || _popupOpen || !mounted) return;
    _popupOpen = true;
    widget.comfort?.cue(GameCue.empty);
    _events?.outOfEnergy();
    await showOutOfMannaPopup(context, session.manna, ads: session.ads);
    _popupOpen = false;
  }
}
