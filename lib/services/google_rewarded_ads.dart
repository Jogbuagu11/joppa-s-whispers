// Rewarded ads from Google Mobile Ads (AdMob).
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/app/config.dart';
import 'package:whispers_of_joppa/services/ad_consent.dart';
import 'package:whispers_of_joppa/services/ad_service.dart';

final _log = Logger('Ads');

const _rewardGrace = Duration(seconds: 1);
const _appearWait = Duration(seconds: 10);

class GoogleRewardedAds implements AdService {
  /// Asks whether ads may be requested (showing the consent message if one
  /// is due). Tests pass their own.
  final Future<bool> Function() _consent;

  GoogleRewardedAds({Future<bool> Function()? consent})
    : _consent = consent ?? gatherAdConsent;

  final ValueNotifier<bool> _ready = ValueNotifier<bool>(false);
  RewardedAd? _ad;
  bool _started = false;
  bool _loading = false;
  int _failures = 0;
  Timer? _expiry;

  @override
  ValueListenable<bool> get ready => _ready;

  String get _unitId => Platform.isIOS
      ? AppConfig.admobRewardedUnitIos
      : AppConfig.admobRewardedUnitAndroid;

  @override
  void start() {
    if (_started) return;
    _started = true;
    unawaited(_initAndLoad());
  }

  Future<void> _initAndLoad() async {
    try {
      // No ad is requested until the consent service says it may be.
      if (!await _consent()) {
        _log.info('Ads not requested: consent not given or not known');
        // Not for ever: the next start() (the player coming back to the
        // game, say) asks again.
        _started = false;
        return;
      }
      await MobileAds.instance.initialize();
      _load();
    } on Object catch (e) {
      // No ads is never a reason to stop the game.
      _log.warning('Ads could not start: $e');
      _started = false;
    }
  }

  void _load() {
    if (_loading || _ad != null) return;
    _loading = true;
    unawaited(
      RewardedAd.load(
        adUnitId: _unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _loading = false;
            _failures = 0;
            _ad = ad;
            _ready.value = true;
            // A loaded ad goes stale after about an hour: swap it for a
            // fresh one before then, so a stale ad is never offered.
            _expiry?.cancel();
            _expiry = Timer(const Duration(minutes: 50), () {
              if (!identical(_ad, ad)) return;
              _ad = null;
              _ready.value = false;
              unawaited(ad.dispose());
              _load();
            });
          },
          onAdFailedToLoad: (error) {
            _loading = false;
            _failures++;
            _log.info('No ad available: ${error.message}');
            // Try again later, waiting longer each time (1, 2, 4... minutes,
            // at most 16).
            final minutes = 1 << (_failures > 4 ? 4 : _failures - 1);
            Timer(Duration(minutes: minutes), _load);
          },
        ),
      ),
    );
  }

  @override
  Future<bool> privacyOptionsRequired() => adPrivacyOptionsRequired();

  @override
  Future<void> showPrivacyOptions() => showAdPrivacyOptions();

  @override
  Future<bool> showRewarded() async {
    final ad = _ad;
    if (ad == null) return false;
    _ad = null;
    _expiry?.cancel();
    _ready.value = false;
    final done = Completer<bool>();
    var earned = false;
    var appeared = false;
    void finish() {
      if (done.isCompleted) return;
      done.complete(earned);
      unawaited(ad.dispose());
      _load();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => appeared = true,
      // The reward can be reported a moment after the ad closes, so wait
      // briefly before deciding whether it was earned.
      onAdDismissedFullScreenContent: (_) => Timer(_rewardGrace, finish),
      onAdFailedToShowFullScreenContent: (_, error) {
        _log.warning('Ad could not be shown: ${error.message}');
        finish();
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      // The plugin can accept the request and then show nothing and say
      // nothing. Do not wait for ever on an ad that never appeared.
      Timer(_appearWait, () {
        if (!appeared) {
          _log.warning('The ad never appeared');
          finish();
        }
      });
    } on Object catch (e) {
      _log.warning('Ad could not be shown: $e');
      finish();
    }
    return done.future;
  }
}
