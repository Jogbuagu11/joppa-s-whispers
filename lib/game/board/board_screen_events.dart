// The board screen's part in events: finding the one that is on, the
// banner that leads to it, and opening the event board.
part of 'board_screen.dart';

mixin _BoardEvents on _BoardRoutes {
  /// Looks for an event that is on now. Runs in the background; the banner
  /// appears if one is found.
  Future<void> _loadEvent() async {
    final events = widget.events;
    if (events == null) return;
    final event = currentEvent(await events.load(), DateTime.now());
    // Always the freshest copy, so a correction on the server is picked up.
    if (mounted && !_eventOpen) setState(() => _event = event);
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
