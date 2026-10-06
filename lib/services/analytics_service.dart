// Analytics and crash reporting, as the game sees them. The real one is in
// firebase_analytics_service.dart; without it (tests, or Firebase not set
// up) nothing is sent anywhere.
abstract class Analytics {
  /// Records that something happened. Never throws.
  void log(String event, [Map<String, Object?> params = const {}]);

  /// Facts attached to crash reports: which content and chapter were in use.
  void setContext({required int contentVersion, String? chapterId});

  /// Reports an error that was caught and handled, so it is still seen.
  void recordError(Object error, StackTrace stack);

  /// Deliberately crashes the app, to check crash reports arrive.
  void testCrash();
}
