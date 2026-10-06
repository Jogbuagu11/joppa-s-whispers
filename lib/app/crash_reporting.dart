// Starts Firebase and sends every uncaught error to Crashlytics.
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/firebase_options.dart';
import 'package:whispers_of_joppa/services/analytics_service.dart';
import 'package:whispers_of_joppa/services/firebase_analytics_service.dart';

final _log = Logger('CrashReporting');

/// Starts Firebase. Returns the analytics service, or null if Firebase could
/// not start: the game then runs exactly the same, just without reports.
Future<Analytics?> startCrashReporting() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final crash = FirebaseCrashlytics.instance;
    // Errors Flutter catches while drawing or handling a tap.
    // A report that cannot be sent is only logged: it must never raise a
    // new error of its own (which would come straight back here).
    void failed(Object e) => _log.warning('Could not send a crash report: $e');
    final showError = FlutterError.onError;
    FlutterError.onError = (details) {
      showError?.call(details);
      unawaited(crash.recordFlutterFatalError(details).catchError(failed));
    };
    // Everything else (errors in background work).
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        crash.recordError(error, stack, fatal: true).catchError(failed),
      );
      return true;
    };
    return FirebaseAnalyticsService();
  } on Object catch (e) {
    _log.warning('Firebase could not start; continuing without it: $e');
    return null;
  }
}
