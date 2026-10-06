import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/game/board/session_content.dart';

import '../support/fakes.dart';

const _v2 = ContentBundle(version: 2, format: 1, files: {});

void main() {
  test('a new game is stamped with the running content version', () {
    final r = contentVersionFor(null, _v2);
    expect(r.contentVersion, 2);
    expect(r.downgraded, isFalse);
  });

  test(
    'a game from the same or older content moves up to the running version',
    () {
      expect(
        contentVersionFor(testSave(contentVersion: 2), _v2).contentVersion,
        2,
      );
      final older = contentVersionFor(testSave(contentVersion: 1), _v2);
      expect(older.contentVersion, 2);
      expect(older.downgraded, isFalse);
    },
  );

  test('a game from newer content is flagged and keeps its higher version', () {
    final r = contentVersionFor(testSave(contentVersion: 5), _v2);
    expect(r.downgraded, isTrue);
    expect(r.contentVersion, 5);
  });
}
