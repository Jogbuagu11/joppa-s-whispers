// Records analytics events instead of sending them.
import 'package:whispers_of_joppa/domain/analytics_events.dart';
import 'package:whispers_of_joppa/services/analytics_service.dart';

class FakeAnalytics implements Analytics {
  /// Every event logged, in order, with the parameters that would be sent.
  final List<(String, Map<String, Object>)> events = [];
  int? contentVersion;
  String? chapterId;
  int crashes = 0;
  final List<Object> errors = [];

  List<String> get names => [for (final e in events) e.$1];

  int count(String name) => names.where((n) => n == name).length;

  @override
  void log(String event, [Map<String, Object?> params = const {}]) =>
      events.add((event, safeParams(params)));

  @override
  void setContext({required int contentVersion, String? chapterId}) {
    this.contentVersion = contentVersion;
    this.chapterId = chapterId;
  }

  @override
  void recordError(Object error, StackTrace stack) => errors.add(error);

  @override
  void testCrash() => crashes++;
}
