// Holds the player's Manna and regenerates it over time.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/economy.dart';

class MannaController extends ChangeNotifier {
  final EconomyConfig config;
  final DateTime Function() _now;
  MannaState _state;
  Timer? _timer;

  MannaController({
    required this.config,
    required int startingManna,
    DateTime? lastRegen,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now,
       _state = MannaState(
         manna: startingManna,
         lastRegen: lastRegen ?? (clock ?? DateTime.now)(),
       );

  /// When the regen clock last ticked (written to the save file).
  DateTime get lastRegen => _state.lastRegen;

  int get manna => _state.manna;
  int get maxManna => config.maxManna;

  /// Seconds until the next Manna, or null when the bar is full.
  int? get secondsUntilNext => secondsUntilNextManna(config, _state, _now());

  /// Starts the once-a-second tick that drives regen and the countdown.
  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Applies any regen that is due and refreshes listeners.
  void tick() {
    _state = applyMannaRegen(config, _state, _now());
    notifyListeners();
  }

  /// Sets Manna after a spend. The regen clock starts now if the bar was full.
  void setAfterSpend(int manna) {
    final wasFull = _state.manna >= config.maxManna;
    _state = MannaState(
      manna: manna,
      lastRegen: wasFull ? _now() : _state.lastRegen,
    );
    notifyListeners();
  }

  /// Adds bought or gifted Manna. It may go above the bar; the bar then
  /// simply stops refilling until Manna is spent back below it.
  void add(int amount) {
    if (amount <= 0) return;
    _state = MannaState(
      manna: _state.manna + amount,
      lastRegen: _state.lastRegen,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
