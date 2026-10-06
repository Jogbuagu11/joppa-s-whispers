// Writes the save file shortly after anything changes, and when the app is
// sent to the background.
import 'dart:async';

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

  /// The longest a change may wait, even if changes keep coming.
  final Duration maxWait;

  /// Called with the state after each successful write (used to send the
  /// save on to the player's account).
  void Function(SaveState state)? onSaved;

  Timer? _timer;
  bool _dirty = false;
  DateTime? _deadline;
  Future<void> _writing = Future<void>.value();

  GameSaver({
    required this.repository,
    required this.snapshot,
    required this.triggers,
    this.delay = const Duration(seconds: 2),
    this.maxWait = const Duration(seconds: 10),
  });

  void start() {
    for (final trigger in triggers) {
      trigger.addListener(_changed);
    }
    WidgetsBinding.instance.addObserver(this);
  }

  void _changed() {
    _dirty = true;
    final now = DateTime.now();
    final deadline = _deadline ??= now.add(maxWait);
    final untilDeadline = deadline.difference(now);
    _timer?.cancel();
    _timer = Timer(untilDeadline < delay ? untilDeadline : delay, flush);
  }

  /// Writes now if anything changed since the last write.
  Future<void> flush() {
    _timer?.cancel();
    if (!_dirty) return _writing;
    _dirty = false;
    _deadline = null;
    final state = snapshot();
    // Writes are queued one after another so they can never overlap.
    return _writing = _writing.then((_) async {
      try {
        await repository.save(state);
        onSaved?.call(state);
      } on Object catch (e, stack) {
        // Whatever went wrong, keep saving: mark the state unsaved so the
        // next change or background event tries again.
        _log.severe('Could not write the save file', e, stack);
        _dirty = true;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) flush();
  }

  /// Stops listening and drops any unsaved change; waits for a write already
  /// under way to finish.
  Future<void> cancel() {
    for (final trigger in triggers) {
      trigger.removeListener(_changed);
    }
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _dirty = false;
    return _writing;
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
