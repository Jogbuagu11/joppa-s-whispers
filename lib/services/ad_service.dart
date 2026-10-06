// Rewarded ads, as the game sees them. The real one is in
// google_rewarded_ads.dart; tests use a stand-in.
import 'package:flutter/foundation.dart';

abstract class AdService {
  /// True while an ad is loaded and can be shown at once. The game only
  /// offers an ad while this is true.
  ValueListenable<bool> get ready;

  /// Starts loading ads. Safe to call more than once.
  void start();

  /// Shows a rewarded ad. Completes with true only if the player watched
  /// enough to earn the reward; false if it was closed early or failed.
  Future<bool> showRewarded();
}
