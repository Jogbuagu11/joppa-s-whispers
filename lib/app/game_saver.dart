// Writes the save file shortly after anything changes, and when the app is
// sent to the background.
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

final _log = Logger('GameSaver');

class GameSaver with WidgetsBindingObserver {
  final SaveRepository repository;

  /// Builds the current game state to write.
  final SaveState Function() snapshot;

  /// Anything that fires when the game changes in a way worth saving.
  final List<Listenable> triggers;

  /// How long to wait after a change before writing, so a burst of moves
  /// becomes one write.
  final Duration delay;

  Timer? _timer;
  bool _dirty = false;
  Future<void> _writing = Future<void>.value();

  GameSaver({
    required this.repository,
    required this.snapshot,
    required this.triggers,
    this.delay = const Duration(seconds: 2),
  });

  void start() {
    for (final trigger in triggers) {
      trigger.addListener(_changed);
    }
    WidgetsBinding.instance.addObserver(this);
  }

  void _changed() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  /// Writes now if anything changed since the last write.
  Future<void> flush() {
    _timer?.cancel();
    if (!_dirty) return _writing;
    _dirty = false;
    final state = snapshot();
    // Writes are queued one after another so they can never overlap.
    return _writing = _writing.then((_) async {
      try {
        await repository.save(state);
      } on FileSystemException catch (e, stack) {
        _log.severe('Could not write the save file', e, stack);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) flush();
  }

  /// Stops listening and writes any unsaved change.
  Future<void> dispose() {
    for (final trigger in triggers) {
      trigger.removeListener(_changed);
    }
    WidgetsBinding.instance.removeObserver(this);
    return flush();
  }
}
