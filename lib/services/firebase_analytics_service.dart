// Analytics and crash reporting through Firebase.
import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/analytics_events.dart';
import 'package:whispers_of_joppa/services/analytics_service.dart';

final _log = Logger('Analytics');

class FirebaseAnalyticsService implements Analytics {
  @override
  void log(String event, [Map<String, Object?> params = const {}]) {
    // Firebase counts sessions itself and refuses that name from an app.
    if (sentByFirebaseItself.contains(event)) return;
    final safe = safeParams(params);
    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: event, parameters: safe.isEmpty ? null : safe)
          .catchError((Object e) => _log.warning('Could not log $event: $e')),
    );
  }

  @override
  void setContext({required int contentVersion, String? chapterId}) {
    final crash = FirebaseCrashlytics.instance;
    unawaited(
      Future.wait([
        crash.setCustomKey('content_version', contentVersion),
        crash.setCustomKey('chapter', chapterId ?? 'none'),
      ]).catchError((Object e) {
        _log.warning('Could not set crash context: $e');
        return <void>[];
      }),
    );
  }

  @override
  void recordError(Object error, StackTrace stack) {
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(error, stack)
          .catchError((Object e) => _log.warning('Could not report: $e')),
    );
  }

  @override
  void testCrash() => FirebaseCrashlytics.instance.crash();
}
