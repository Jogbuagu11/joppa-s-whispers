// An in-memory stand-in for the ad service.
import 'dart:async';

import 'package:flutter/foundation.dart';
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
