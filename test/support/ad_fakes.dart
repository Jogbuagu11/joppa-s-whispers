// An in-memory stand-in for the ad service.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:whispers_of_joppa/services/ad_service.dart';

class FakeAdService implements AdService {
  final ValueNotifier<bool> _ready;

  FakeAdService({bool ready = true}) : _ready = ValueNotifier<bool>(ready);

  /// Whether the next ad is watched to the end.
  bool watchedToEnd = true;

  /// When true, showing the ad throws.
  bool throwOnShow = false;
  int shown = 0;
  int starts = 0;

  set isReady(bool value) => _ready.value = value;

  @override
  ValueListenable<bool> get ready => _ready;

  @override
  void start() => starts++;

  /// What stands in for the banner; null (the usual) means no banners.
  Widget? fakeBanner;

  @override
  Widget? banner() => fakeBanner;

  /// Whether this player has ad privacy choices to change.
  bool privacyRequired = false;
  int privacyShown = 0;

  @override
  Future<bool> privacyOptionsRequired() async => privacyRequired;

  @override
  Future<void> showPrivacyOptions() async => privacyShown++;

  @override
  Future<bool> showRewarded() async {
    shown++;
    if (throwOnShow) throw Exception('ad broke');
    final gate = hold;
    if (gate != null) await gate.future;
    return watchedToEnd;
  }

  /// If set, the ad stays on screen until this completes.
  Completer<void>? hold;
}
