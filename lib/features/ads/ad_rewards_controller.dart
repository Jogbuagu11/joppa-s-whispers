// Optional rewarded ads: the player may choose to watch one for bonus Manna,
// a limited number of times a day. Nothing here ever shows an ad by itself.
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/ads.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/services/ad_service.dart';

final _log = Logger('AdRewards');

class AdRewardsController extends ChangeNotifier {
  final EconomyConfig config;

  /// Adds the reward to the player's Manna.
  final void Function(int amount) addManna;

  /// No ads are offered until the tutorial is over.
  final bool Function() tutorialOver;
  final DateTime Function() _now;

  AdService? _service;
  AdTally _tally;
  bool _showing = false;
  bool _disposed = false;

  /// Fires only when the count of ads watched changes (the part of this
  /// that is saved), not when an ad merely becomes ready.
  final ValueNotifier<int> tallyChanged = ValueNotifier<int>(0);

  AdRewardsController({
    required this.config,
    required this.addManna,
    required this.tutorialOver,
    AdTally startingTally = const AdTally(),
    DateTime Function()? clock,
  }) : _tally = startingTally,
       _now = clock ?? DateTime.now;

  /// Written to the save file.
  AdTally get tally => _tally;

  /// The Manna one ad gives.
  int get mannaReward => config.rewardedAdMannaBonus;

  int get mannaAdsLeft => mannaAdsLeftToday(config, _tally, _now());

  /// Connects the ad service (null where ads are not set up, as in tests).
  set service(AdService? value) {
    _service?.ready.removeListener(notifyListeners);
    _service = value;
    value?.ready.addListener(notifyListeners);
    notifyListeners();
  }

  /// Starts loading ads once the tutorial is over, and not before: starting
  /// can bring up a consent message, which must never greet a new player.
  /// The board calls this at quiet moments (nothing else open). Safe to
  /// call often; a start that could not get consent is tried again.
  void startWhenAllowed() {
    if (_disposed || !tutorialOver()) return;
    _service?.start();
  }

  /// Whether to show the "watch an ad" choice: only when an ad is loaded and
  /// ready, the tutorial is over and today's allowance is not used up.
  bool get mannaAdOffered =>
      !_showing &&
      (_service?.ready.value ?? false) &&
      canOfferMannaAd(config, _tally, _now(), tutorialOver: tutorialOver());

  /// Shows an ad the player asked for. The Manna is given only if the ad was
  /// watched to the end. Returns whether it was.
  Future<bool> watchForManna() async {
    final service = _service;
    if (service == null || !mannaAdOffered) return false;
    _showing = true;
    notifyListeners();
    var earned = false;
    try {
      earned = await service.showRewarded();
    } on Exception catch (e) {
      // A broken ad gives nothing and must never disturb the game.
      _log.warning('The ad could not be shown: $e');
    } finally {
      _showing = false;
    }
    // The game may have been closed or replaced while the ad was playing.
    if (_disposed) return false;
    if (earned) {
      _tally = afterMannaAd(_tally, _now());
      addManna(mannaReward);
      tallyChanged.value++;
    }
    notifyListeners();
    return earned;
  }

  /// Whether an ad can be shown for some other reward the player asks for
  /// (keeping a bubble's item): one is loaded and the tutorial is over.
  bool get rewardAdReady =>
      !_showing &&
      !_disposed &&
      tutorialOver() &&
      (_service?.ready.value ?? false);

  /// Shows an ad the player asked for, for a reward the caller gives.
  /// Returns whether it was watched to the end. It does not count towards
  /// the day's Manna ads.
  Future<bool> watchForReward() async {
    final service = _service;
    if (service == null || !rewardAdReady) return false;
    _showing = true;
    notifyListeners();
    var earned = false;
    try {
      earned = await service.showRewarded();
    } on Exception catch (e) {
      // A broken ad gives nothing and must never disturb the game.
      _log.warning('The ad could not be shown: $e');
    } finally {
      _showing = false;
    }
    if (_disposed) return false;
    notifyListeners();
    return earned;
  }

  @override
  void dispose() {
    _disposed = true;
    _service?.ready.removeListener(notifyListeners);
    tallyChanged.dispose();
    super.dispose();
  }
}
