// The Blessing Wheel's state: which spins are left today, and spinning.
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/chance.dart';
import 'package:whispers_of_joppa/domain/wheel.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

/// The name of the wheel's record in the save file.
const wheelRecord = 'wheel';

class WheelController extends ChangeNotifier {
  final WheelRules rules;
  final SaveExtras extras;

  /// False where the law forbids buying random rewards: no Pearl spins.
  final bool paidAllowed;
  final int Function() pearls;

  /// Takes Pearls; false (taking nothing) if there are not enough.
  final bool Function(int amount) spendPearls;

  /// Hands a prize to the player.
  final void Function(Prize prize) grant;

  /// Whether an ad is ready to be watched, and watching one (true if it
  /// was watched to the end).
  final bool Function() adReady;
  final Future<bool> Function() watchAd;
  final Random _random;
  final DateTime Function() _now;
  bool _busy = false;
  bool _disposed = false;

  WheelController({
    required this.rules,
    required this.extras,
    required this.paidAllowed,
    required this.pearls,
    required this.spendPearls,
    required this.grant,
    required this.adReady,
    required this.watchAd,
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random(),
       _now = clock ?? DateTime.now;

  WheelTally get _tally => WheelTally.fromJson(extras.read(wheelRecord));

  /// True while a spin is being paid for (an ad is playing).
  bool get busy => _busy;

  int get freeSpins => freeSpinsLeft(rules, _tally, _now());

  /// Ad spins left today, whether or not an ad is ready.
  int get adSpins => adSpinsLeft(rules, _tally, _now());
  bool get adSpinOffered => !_busy && adSpins > 0 && adReady();

  /// The price of the next Pearl spin; null if there is none to be had
  /// (the day's are used up, or they are not allowed here).
  int? get pearlSpinPrice =>
      paidAllowed ? pearlSpinCost(rules, _tally, _now()) : null;

  /// The prizes of a free (or ad) spin, and of a Pearl spin, with their
  /// chances: exactly what [spin] draws from.
  List<PrizeOdds> get freeOdds => oddsFor(rules.prizes, paid: false);
  List<PrizeOdds> get paidOdds => oddsFor(rules.prizes, paid: true);

  /// Spins once, paid for by [kind]. Returns the prize, already given, or
  /// null (nothing taken, nothing given) if that spin was not to be had.
  Future<Prize?> spin(SpinKind kind) async {
    if (_busy || _disposed) return null;
    final paid = kind == SpinKind.pearls;
    // Nothing is taken unless there is a prize to give for it.
    if (oddsFor(rules.prizes, paid: paid).isEmpty) return null;
    switch (kind) {
      case SpinKind.free:
        if (freeSpins == 0) return null;
      case SpinKind.ad:
        if (!adSpinOffered) return null;
        _busy = true;
        notifyListeners();
        var watched = false;
        try {
          watched = await watchAd();
        } finally {
          _busy = false;
        }
        if (_disposed) return null;
        if (!watched) {
          notifyListeners();
          return null;
        }
      case SpinKind.pearls:
        final price = pearlSpinPrice;
        if (price == null || !spendPearls(price)) return null;
    }
    final prize = drawPrize(rules.prizes, paid: paid, random: _random);
    extras.write(wheelRecord, afterSpin(_tally, kind, _now()).toJson());
    if (prize != null) grant(prize);
    notifyListeners();
    return prize;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
