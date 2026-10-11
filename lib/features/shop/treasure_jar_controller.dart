// The player's Treasure Jar: it fills as they play, and a confirmed
// purchase opens it. Kept in the save file under its own name.
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/treasure_jar.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

/// The name of the jar's record in the save file.
const treasureJarRecord = 'treasure';

class TreasureJarController {
  final TreasureJarRules rules;
  final SaveExtras extras;

  /// The player's level when last looked at.
  int level;

  TreasureJarController({
    required this.rules,
    required this.extras,
    required this.level,
  });

  TreasureJarState get state =>
      TreasureJarState.fromJson(extras.read(treasureJarRecord));

  /// The jar the player has now.
  JarSize get size => rules.sizeAfter(state.opened);
  bool get isFull => jarIsFull(rules, state);

  /// True once, when the jar has filled and the player has not been told.
  bool get newlyFull => isFull && !state.toldFull;

  void _save(int pearls) {
    final before = state;
    final after = jarAfterSaving(rules, before, pearls);
    if (after.saved == before.saved) return;
    extras.write(treasureJarRecord, after.toJson());
  }

  void orderDelivered() => _save(rules.perOrder);
  void taskDone() => _save(rules.perTask);

  /// The player's level is [now]: each level won since the last
  /// look saves its Pearls.
  void levelIs(int now) {
    final won = now - level;
    if (won <= 0) return;
    level = now;
    _save(rules.perLevel * won);
  }

  /// The player has seen that the jar is full.
  void toldFull() {
    if (!newlyFull) return;
    extras.write(treasureJarRecord, jarToldFull(state).toJson());
  }

  /// Purchases just put into the game: each one that opened a jar leaves
  /// an empty, bigger jar. (Its Pearls came with the purchase.)
  void purchasesApplied(List<PurchaseRecord> applied) {
    final times = applied.where((r) => rules.isJarProduct(r.productId)).length;
    if (times == 0) return;
    extras.write(
      treasureJarRecord,
      jarAfterOpening(state, times: times).toJson(),
    );
  }
}
