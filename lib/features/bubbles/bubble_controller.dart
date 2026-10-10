// The bubbles afloat over the board (EXPANSION 20.1): which there are, how
// long each has left, and what becomes of it.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/bubbles.dart';
import 'package:whispers_of_joppa/domain/lucky.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';

/// One bubble: the item in it, the cell it floats over, and when it pops.
class Bubble {
  final int id;
  final ItemModel item;
  final int col;
  final int row;
  final DateTime popsAt;

  /// True for a mystery bubble: [item] is the item that was merged, and
  /// what the bubble really holds is only drawn when it is kept.
  final bool mystery;

  const Bubble({
    required this.id,
    required this.item,
    required this.col,
    required this.row,
    required this.popsAt,
    this.mystery = false,
  });
}

class BubbleController extends ChangeNotifier {
  /// The numbers bubbles go by; null if the game has no bubbles.
  final BubbleRules? rules;
  final Map<String, ItemModel> items;
  final Map<String, ChainTierData> chains;

  /// Chains no generator makes (rare finds, gifts): never kept for an ad.
  final Set<String> sideChains;

  /// Mystery bubbles; null where there are none (the game has none, or
  /// buying random rewards is forbidden here).
  final MysteryBubble? mystery;

  /// What the last bubble kept turned out to hold.
  ItemModel? lastKept;

  /// False while there are to be no new bubbles (before their level, and
  /// during the tutorial).
  final bool Function() allowed;

  /// Pays the Talents of a bubble that popped by itself.
  final void Function(int talents) addTalents;

  /// Takes Pearls; false (taking nothing) if there are not enough.
  final bool Function(int pearls) spendPearls;

  /// Hands the kept item to the board (it waits if there is no room).
  final void Function(String itemId) giveItem;

  final Random _random;
  final DateTime Function() _now;
  final List<Bubble> _bubbles = [];
  final Set<int> _held = {};
  Timer? _timer;
  int _nextId = 1;
  bool _disposed = false;

  BubbleController({
    required this.rules,
    required this.items,
    required this.chains,
    this.sideChains = const {},
    this.mystery,
    required this.allowed,
    required this.addTalents,
    required this.spendPearls,
    required this.giveItem,
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random(),
       _now = clock ?? DateTime.now;

  List<Bubble> get bubbles => List.unmodifiable(_bubbles);

  /// Seconds the bubble with [id] has left (0 if it is gone).
  int secondsLeft(int id) {
    final left = byId(id)?.popsAt.difference(_now()).inMilliseconds ?? 0;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  /// The share (0 to 1) of its time that the bubble with [id] has left.
  double shareLeft(int id) {
    final whole = (rules?.seconds ?? 0) * 1000;
    final bubble = byId(id);
    if (whole <= 0 || bubble == null) return 0;
    final left = bubble.popsAt.difference(_now()).inMilliseconds;
    return (left / whole).clamp(0.0, 1.0);
  }

  int pearlsFor(Bubble bubble) => rules?.pearlsFor(bubble.item.tier) ?? 0;
  int talentsFor(Bubble bubble) => rules?.talentsFor(bubble.item.tier) ?? 0;
  bool adAllowedFor(Bubble bubble) =>
      !sideChains.contains(bubble.item.chainId) &&
      (rules?.adAllowedFor(bubble.item.tier) ?? false);

  /// The bubble with [id] as it is now, or null if it is gone.
  Bubble? byId(int id) => _bubbles.where((b) => b.id == id).firstOrNull;

  /// Called after every merge with the item made and where it is. Now and
  /// then this leaves a bubble.
  void afterMerge(ItemModel merged, {required int col, required int row}) {
    final rules = this.rules;
    if (_disposed || rules == null || !allowed()) return;
    // Never a second Manna jar, hourglass, tool or sealed jar.
    if (merged.use != null) return;
    if (_bubbles.length >= rules.maxAtOnce) return;
    final drawn =
        items[bubbleAfterMerge(merged, rules, chains, random: _random)];
    if (drawn == null) return;
    // A mystery bubble starts from the plain item; its lift is drawn when
    // it is kept.
    final mystery = _isMystery();
    final held = mystery ? merged : drawn;
    _bubbles.add(
      Bubble(
        id: _nextId++,
        item: held,
        col: col,
        row: row,
        popsAt: _now().add(Duration(seconds: rules.seconds)),
        mystery: mystery,
      ),
    );
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  /// Pops every bubble whose time is up, paying its Talents. Called each
  /// second while there are bubbles.
  void tick() {
    if (_disposed) return;
    final now = _now();
    final done = [
      for (final b in _bubbles)
        if (!b.popsAt.isAfter(now) && !_held.contains(b.id)) b,
    ];
    for (final bubble in done) {
      _bubbles.remove(bubble);
      final talents = talentsFor(bubble);
      if (talents > 0) addTalents(talents);
    }
    _rest();
    notifyListeners();
  }

  /// Keeps the item of the bubble with [id] for Pearls. Returns false,
  /// changing nothing, if it is gone or there are not enough Pearls.
  bool keepWithPearls(int id) {
    final bubble = byId(id);
    if (_disposed || bubble == null) return false;
    if (!spendPearls(pearlsFor(bubble))) return false;
    _keep(bubble);
    return true;
  }

  /// Keeps the item of the bubble with [id] after an ad was watched to the
  /// end. Returns false, changing nothing, if it is gone or too big for an
  /// ad.
  bool keepAfterAd(int id) {
    final bubble = byId(id);
    if (_disposed || bubble == null || !adAllowedFor(bubble)) return false;
    _keep(bubble);
    return true;
  }

  /// Keeps the bubble with [id] from popping while the player is deciding
  /// about it or watching an ad for it, until [release].
  void hold(int id) {
    if (!_disposed && byId(id) != null) _held.add(id);
  }

  /// Lets a held bubble go on as before; if its time ran out meanwhile it
  /// pops at the next tick.
  void release(int id) => _held.remove(id);

  bool _isMystery() {
    final mystery = this.mystery;
    return mystery != null && _random.nextDouble() < mystery.share;
  }

  void _keep(Bubble bubble) {
    _bubbles.remove(bubble);
    _held.remove(bubble.id);
    // A mystery bubble's item is drawn now, by the odds it showed.
    final lift = bubble.mystery ? (mystery?.draw(random: _random) ?? 0) : 0;
    final kept = items[liftedItemId(bubble.item, lift, chains)] ?? bubble.item;
    lastKept = kept;
    giveItem(kept.itemId);
    _rest();
    notifyListeners();
  }

  void _rest() {
    if (_bubbles.isNotEmpty) return;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
