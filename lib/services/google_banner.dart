// The banner ad under the board, from Google Mobile Ads (AdMob).
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/app/config.dart';

final _log = Logger('Banner');

class GoogleBanner extends StatefulWidget {
  const GoogleBanner({super.key, required this.mayRequest});

  /// True once consent is settled and the ads library is running. No
  /// banner is asked for before then.
  final ValueListenable<bool> mayRequest;

  @override
  State<GoogleBanner> createState() => _GoogleBannerState();
}

class _GoogleBannerState extends State<GoogleBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    widget.mayRequest.addListener(_load);
    _load();
  }

  void _load() {
    if (_ad != null || !widget.mayRequest.value || !mounted) return;
    final ad = BannerAd(
      adUnitId: Platform.isIOS
          ? AppConfig.admobBannerUnitIos
          : AppConfig.admobBannerUnitAndroid,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // No banner is never a reason to disturb the game: the space
          // simply stays empty, and another is asked for in a while.
          _log.info('No banner available: ${error.message}');
          unawaited(ad.dispose());
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
          _retry?.cancel();
          _retry = Timer(const Duration(minutes: 2), _load);
        },
      ),
    );
    _ad = ad;
    unawaited(ad.load());
  }

  @override
  void dispose() {
    widget.mayRequest.removeListener(_load);
    _retry?.cancel();
    unawaited(_ad?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
