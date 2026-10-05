// What screens outside the board may ask of it, without depending on Flame.
import 'package:flutter/foundation.dart';

abstract class BoardInventory {
  /// item_id -> how many are on the board right now.
  Map<String, int> itemCounts();

  /// Takes the given number of each item off the board. Returns false,
  /// removing nothing, if the board does not hold them all.
  bool removeItems(Map<String, int> counts);

  /// Fires whenever the items on the board change.
  Listenable get boardChanged;
}
