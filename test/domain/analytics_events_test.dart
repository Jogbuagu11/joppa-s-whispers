import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/analytics_events.dart';

void main() {
  test('frequent events: the first is sent, then one in every ten', () {
    final sent = [
      for (var n = 1; n <= 25; n++)
        if (isSampled(n)) n,
    ];
    expect(sent, [1, 11, 21]);
  });

  test('sampling every 1 (or nonsense) sends everything', () {
    expect(isSampled(7, every: 1), isTrue);
    expect(isSampled(7, every: 0), isTrue);
    expect(isSampled(0), isFalse);
  });

  test('only allowed keys with plain values are sent', () {
    expect(
      safeParams({
        'order_id': 'ch1_o_001',
        'step': 3,
        'email': 'someone@example.com',
        'user_id': 'abc',
        'task_id': null,
        'product_id': ['not', 'plain'],
        'letter_id': 'x' * 101,
      }),
      {'order_id': 'ch1_o_001', 'step': 3},
    );
    expect(safeParams({}), isEmpty);
  });

  test('newly delivered purchases are found by comparing before and after', () {
    expect(
      newlyAppliedProducts({'t1'}, {'t1', 't2', 't3'}, {
        't1': 'pearls_tier1',
        't2': 'starter_pack',
        't3': 'pearls_tier2',
      }),
      unorderedEquals(['starter_pack', 'pearls_tier2']),
    );
    expect(
      newlyAppliedProducts({'t1'}, {'t1'}, {'t1': 'pearls_tier1'}),
      isEmpty,
    );
    // A transaction the server list does not name is not guessed at.
    expect(newlyAppliedProducts({}, {'tx'}, {}), isEmpty);
  });

  test('every event name is one Firebase accepts', () {
    expect(allAnalyticsEvents.toSet(), hasLength(14));
    for (final name in allAnalyticsEvents) {
      expect(isValidEventName(name), isTrue, reason: name);
    }
    expect(isValidEventName('firebase_thing'), isFalse);
    expect(isValidEventName('9lives'), isFalse);
    expect(isValidEventName('has space'), isFalse);
    expect(isValidEventName('x' * 41), isFalse);
  });

  test('session_start is left to Firebase, which records it itself', () {
    expect(sentByFirebaseItself, {AnalyticsEvent.sessionStart});
    expect(sentByFirebaseItself.contains(AnalyticsEvent.sessionEnd), isFalse);
  });
}
