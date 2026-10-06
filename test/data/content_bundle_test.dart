import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';

import '../support/content_fixtures.dart';

void main() {
  group('ContentBundle', () {
    test('the app\'s own content has no problems', () {
      expect(realContent().problems(), isEmpty);
    });

    test('survives being written and read back', () {
      final back = ContentBundle.fromJson(
        jsonDecode(jsonEncode(realContent(version: 7).toJson()))
            as Map<String, dynamic>,
      );
      expect(back.version, 7);
      expect(back.format, 1);
      expect(back.files.keys, containsAll(contentFileNames));
      expect(back.problems(), isEmpty);
    });

    test('rejects something that is not a bundle', () {
      expect(
        () => ContentBundle.fromJson({'version': 'one'}),
        throwsFormatException,
      );
    });

    test(
      'reports a missing file, a bad rule, a newer format, a bad version',
      () {
        final files = Map<String, Object?>.of(realContent().files)
          ..remove('orders');
        expect(
          ContentBundle(version: 2, format: 1, files: files).problems().single,
          contains('"orders" is missing'),
        );
        expect(brokenContent(2).problems(), isNotEmpty);
        expect(
          realContent(
            version: 2,
            format: supportedContentFormat + 1,
          ).problems().single,
          contains('needs a newer version of the app'),
        );
        expect(
          realContent(version: 0).problems().single,
          contains('1 or more'),
        );
      },
    );

    test('a checked bundle loads into the game', () {
      final loader = ContentLoader()..loadFromBundle(realContent(version: 3));
      expect(loader.isLoaded, isTrue);
      expect(loader.contentVersion, 3);
      expect(loader.items, isNotEmpty);
    });
  });

  group('chooseContent', () {
    test('uses the app\'s content when nothing was downloaded', () {
      expect(chooseContent(bundled: realContent(), cached: null).version, 1);
    });
    test('uses a newer, sound download', () {
      expect(
        chooseContent(
          bundled: realContent(),
          cached: realContent(version: 2),
        ).version,
        2,
      );
    });
    test('ignores a download that is not newer than the app\'s', () {
      expect(
        chooseContent(
          bundled: realContent(version: 5),
          cached: realContent(version: 5),
        ).version,
        5,
      );
      expect(
        chooseContent(
          bundled: realContent(version: 5),
          cached: realContent(version: 3),
        ).version,
        5,
      );
    });
    test('ignores a newer download that has problems', () {
      final bundled = realContent();
      expect(
        identical(
          chooseContent(bundled: bundled, cached: brokenContent(2)),
          bundled,
        ),
        isTrue,
      );
    });
  });
}
