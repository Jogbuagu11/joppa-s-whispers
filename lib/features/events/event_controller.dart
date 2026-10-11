// A player's run at one event: points earned by merging on the event
// board, and the rewards those points unlock.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/domain/events.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';

PassTier _freeTier() => PassTier.free;

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

  /// The season pass tier this player holds for the event (the server's
  /// purchase records decide it), and handing over what only a pass pays.
  final PassTier Function() tier;
  final void Function(int amount)? addPearls;
  final void Function(List<String> itemIds)? giveItems;

  int _points;
  int _paid;
  int _premiumPaid;
  int _endlessPaid;
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
    this.tier = _freeTier,
    this.addPearls,
    this.giveItems,
    DateTime Function()? clock,
  }) : _points = progress.points < 0 ? 0 : progress.points,
       _premiumPaid = progress.premiumPaid < 0 ? 0 : progress.premiumPaid,
       _endlessPaid = progress.endlessPaid < 0 ? 0 : progress.endlessPaid,
       _paid = progress.paid.clamp(0, event.milestones.length),
       _now = clock ?? DateTime.now;

  /// The points that count: Premium Plus adds its bonus to those earned.
  int get points => passPoints(_points, tier(), event.pass);

  /// Reward steps already paid out.
  int get paid => _paid;

  EventMilestone? get next => nextMilestone(event.milestones, points);
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
    settle();
    save();
  }

  /// The Premium rewards and endless steps just paid (season pass).
  final ValueNotifier<List<PassReward>> justPaidPass =
      ValueNotifier<List<PassReward>>(const []);

  int get premiumPaid => _premiumPaid;
  int get endlessPaid => _endlessPaid;

  /// Pays everything the player's points and pass have earned and not yet
  /// had. Called after every merge, and when the pass changes: a pass
  /// bought late pays what was already reached. Returns whether anything
  /// was paid (the caller then saves).
  bool settle() {
    final held = tier();
    final due = milestonesToPay(event.milestones, points, _paid);
    // Counted as paid before anything is handed over, so nothing that
    // happens while handing over can pay the same step twice.
    _paid += due.length;
    for (final step in due) {
      _gameSaveOwed = true;
      if (step.manna > 0) addManna(step.manna);
      if (step.talents > 0) addTalents(step.talents);
    }
    final pass = event.pass;
    final extra = <PassReward>[
      ...premiumToPay(
        pass,
        held,
        reached: milestonesReached(event.milestones, points),
        alreadyPaid: _premiumPaid,
      ),
    ];
    _premiumPaid += extra.length;
    final steps = event.milestones.isEmpty
        ? 0
        : endlessReached(
                pass,
                held,
                points: points,
                lastMilestone: event.milestones.last.points,
              ) -
              _endlessPaid;
    for (var i = 0; i < steps; i++) {
      _endlessPaid++;
      if (pass != null) extra.add(pass.endless);
    }
    for (final reward in extra) {
      _gameSaveOwed = true;
      if (reward.manna > 0) addManna(reward.manna);
      if (reward.talents > 0) addTalents(reward.talents);
      if (reward.pearls > 0) addPearls?.call(reward.pearls);
      if (reward.items.isNotEmpty) giveItems?.call(reward.items);
    }
    if (due.isNotEmpty) justPaid.value = due;
    if (extra.isNotEmpty) justPaidPass.value = extra;
    notifyListeners();
    return due.isNotEmpty || extra.isNotEmpty;
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
          premiumPaid: _premiumPaid,
          endlessPaid: _endlessPaid,
          items: boardItems(),
        ),
      );
    }();
  }

  @override
  void dispose() {
    justPaid.dispose();
    justPaidPass.dispose();
    super.dispose();
  }
}
