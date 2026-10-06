// A player's run at one event: points earned by merging on the event
// board, and the rewards those points unlock.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/domain/events.dart';

class EventController extends ChangeNotifier {
  final EventModel event;
  final EventProgressRepository repository;

  /// Pay rewards into the main game.
  final void Function(int amount) addManna;
  final void Function(int amount) addTalents;

  /// Writes the main game now, so a reward just paid (or Manna just spent)
  /// survives the app being closed.
  final Future<void> Function() saveGame;

  /// The items on the event board right now (written with the progress).
  List<EventItem> Function() boardItems = () => const [];
  final DateTime Function() _now;

  int _points;
  int _paid;
  Future<void>? _saving;

  // True from the moment a reward is paid until the main game is written.
  bool _gameSaveOwed = false;

  EventController({
    required this.event,
    required EventProgress progress,
    required this.repository,
    required this.addManna,
    required this.addTalents,
    required this.saveGame,
    DateTime Function()? clock,
  }) : _points = progress.points < 0 ? 0 : progress.points,
       _paid = progress.paid.clamp(0, event.milestones.length),
       _now = clock ?? DateTime.now;

  int get points => _points;

  /// Reward steps already paid out.
  int get paid => _paid;

  EventMilestone? get next => nextMilestone(event.milestones, _points);
  bool get trackFinished => next == null;
  bool get isLive => isEventLive(event, _now());
  Duration get timeLeft => eventTimeLeft(event, _now());

  /// The latest rewards paid, for the screen to announce (then cleared).
  final ValueNotifier<List<EventMilestone>> justPaid =
      ValueNotifier<List<EventMilestone>>(const []);

  /// Two items merged on the event board into one of [resultTier]. Points
  /// stop counting once the event has ended.
  void onMerged(int resultTier) {
    if (!isLive) return;
    _points += eventPointsForMerge(resultTier);
    final due = milestonesToPay(event.milestones, _points, _paid);
    for (final step in due) {
      // Counted as paid before it is handed over, so one merge cannot pay
      // the same step twice.
      _paid++;
      _gameSaveOwed = true;
      if (step.manna > 0) addManna(step.manna);
      if (step.talents > 0) addTalents(step.talents);
    }
    if (due.isNotEmpty) justPaid.value = due;
    notifyListeners();
    save();
  }

  /// Writes progress and the event board to the phone. Writes run one after
  /// another, each with the state at the time it runs. Whenever a reward has
  /// been paid (or with [gameFirst]) the main game is written before the
  /// progress, so progress never says "paid" for a reward the saved game
  /// does not hold. (A crash between the two can pay a step again; it can
  /// never lose one.)
  Future<void> save({bool gameFirst = false}) {
    final before = _saving;
    return _saving = () async {
      if (before != null) await before;
      if (gameFirst || _gameSaveOwed) {
        _gameSaveOwed = false;
        await saveGame();
      }
      await repository.save(
        EventProgress(
          eventId: event.id,
          points: _points,
          paid: _paid,
          items: boardItems(),
        ),
      );
    }();
  }

  @override
  void dispose() {
    justPaid.dispose();
    super.dispose();
  }
}
