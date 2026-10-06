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
    _events?.outOfEnergy();
    await showOutOfMannaPopup(context, session.manna, ads: session.ads);
    _popupOpen = false;
  }

  /// The slim banner shown on the board while an event is on.
  Widget _eventBanner(EventModel event) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
    child: Material(
      color: const Color(0xFF3A2A0C),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: const Key('event_banner'),
        borderRadius: BorderRadius.circular(10),
        onTap: _openEvent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.celebration_outlined, color: Color(0xFFD4802A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF3E5C8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                formatTimeLeft(eventTimeLeft(event, DateTime.now())),
                style: const TextStyle(color: Color(0xFFD4802A)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
