import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/content_repository.dart';

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

/// The real content shipped in the app, at the given version.
ContentBundle _real({int version = 1, int format = 1}) => ContentBundle(
  version: version,
  format: format,
  files: {for (final name in contentFileNames) name: _read(name)},
);

/// A bundle that parses but breaks a content rule.
ContentBundle _broken(int version) {
  final files = Map<String, Object?>.of(_real().files);
  files['economy'] = {'max_manna': 0};
  return ContentBundle(version: version, format: 1, files: files);
}

class _FakeRemote implements RemoteContent {
  ({int version, String path})? release;
  String body = '';
  bool offline = false;
  int downloads = 0;

  void publish(ContentBundle bundle, {int? asVersion}) {
    release = (version: asVersion ?? bundle.version, path: 'v.json');
    body = jsonEncode(bundle.toJson());
  }

  @override
  Future<({int version, String path})?> latest() async {
    if (offline) throw const SocketException('offline');
    return release;
  }

  @override
  Future<String> download(String path) async {
    downloads++;
    return body;
  }
}

void main() {
  late Directory dir;
  late _FakeRemote remote;
  late ContentRepository repo;

  File cache() => File('${dir.path}/content_cache.json');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('joppa_content_test');
    remote = _FakeRemote();
    repo = ContentRepository(
      loadBundled: () async => _real(),
      remote: remote,
      directory: () async => dir,
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('ContentBundle', () {
    test('the app\'s own content has no problems', () {
      expect(_real().problems(), isEmpty);
    });

    test('survives being written and read back', () {
      final back = ContentBundle.fromJson(
        jsonDecode(jsonEncode(_real(version: 7).toJson()))
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
        final files = Map<String, Object?>.of(_real().files)..remove('orders');
        expect(
          ContentBundle(version: 2, format: 1, files: files).problems().single,
          contains('"orders" is missing'),
        );
        expect(_broken(2).problems(), isNotEmpty);
        expect(
          _real(version: 2, format: 2).problems().single,
          contains('needs a newer version of the app'),
        );
        expect(_real(version: 0).problems().single, contains('1 or more'));
      },
    );

    test('a checked bundle loads into the game', () {
      final loader = ContentLoader()..loadFromBundle(_real(version: 3));
      expect(loader.isLoaded, isTrue);
      expect(loader.contentVersion, 3);
      expect(loader.items, isNotEmpty);
    });
  });

  group('chooseContent', () {
    test('uses the app\'s content when nothing was downloaded', () {
      expect(chooseContent(bundled: _real(), cached: null).version, 1);
    });
    test('uses a newer, sound download', () {
      expect(
        chooseContent(bundled: _real(), cached: _real(version: 2)).version,
        2,
      );
    });
    test('ignores a download that is not newer than the app\'s', () {
      expect(
        chooseContent(
          bundled: _real(version: 5),
          cached: _real(version: 5),
        ).version,
        5,
      );
      expect(
        chooseContent(
          bundled: _real(version: 5),
          cached: _real(version: 3),
        ).version,
        5,
      );
    });
    test('ignores a newer download that has problems', () {
      final bundled = _real();
      expect(
        identical(chooseContent(bundled: bundled, cached: _broken(2)), bundled),
        isTrue,
      );
    });
  });

  group('ContentRepository', () {
    test('with nothing downloaded, plays the app\'s content', () async {
      expect((await repo.current()).version, 1);
    });

    test('a newer release is downloaded for the next launch', () async {
      remote.publish(_real(version: 2));
      final current = await repo.current();
      expect(await repo.checkForUpdate(current), ContentUpdate.downloaded);
      // This launch keeps what it started with...
      expect(current.version, 1);
      // ...and the next launch gets the new content.
      expect((await repo.current()).version, 2);
    });

    test('nothing newer on the server: nothing downloaded', () async {
      remote.publish(_real(version: 1));
      expect(
        await repo.checkForUpdate(await repo.current()),
        ContentUpdate.none,
      );
      expect(remote.downloads, 0);
      remote.release = null;
      expect(
        await repo.checkForUpdate(await repo.current()),
        ContentUpdate.none,
      );
    });

    test(
      'a release that breaks the rules is rejected and never used',
      () async {
        remote.publish(_broken(2));
        expect(
          await repo.checkForUpdate(await repo.current()),
          ContentUpdate.rejected,
        );
        expect(cache().existsSync(), isFalse);
        expect((await repo.current()).version, 1);
      },
    );

    test(
      'a release whose file does not match its version is rejected',
      () async {
        remote.publish(_real(version: 2), asVersion: 3);
        expect(
          await repo.checkForUpdate(await repo.current()),
          ContentUpdate.rejected,
        );
      },
    );

    test('a release for a newer app is rejected', () async {
      remote.publish(_real(version: 2, format: 2));
      expect(
        await repo.checkForUpdate(await repo.current()),
        ContentUpdate.rejected,
      );
    });

    test('a damaged download or no connection never crashes', () async {
      remote.release = (version: 2, path: 'v.json');
      remote.body = '{ not json';
      expect(
        await repo.checkForUpdate(await repo.current()),
        ContentUpdate.failed,
      );
      remote.offline = true;
      expect(
        await repo.checkForUpdate(await repo.current()),
        ContentUpdate.failed,
      );
      expect((await repo.current()).version, 1);
    });

    test(
      'a damaged or unsound saved download is removed and ignored',
      () async {
        cache().writeAsStringSync('{ not json');
        expect((await repo.current()).version, 1);
        expect(cache().existsSync(), isFalse);

        cache().writeAsStringSync(jsonEncode(_broken(2).toJson()));
        expect((await repo.current()).version, 1);
        expect(cache().existsSync(), isFalse);
      },
    );

    test('an app update with newer content than the download wins', () async {
      cache().writeAsStringSync(jsonEncode(_real(version: 2).toJson()));
      final newer = ContentRepository(
        loadBundled: () async => _real(version: 3),
        directory: () async => dir,
      );
      expect((await newer.current()).version, 3);
      expect(cache().existsSync(), isFalse);
    });

    test('with no server configured, there is nothing to check', () async {
      final local = ContentRepository(
        loadBundled: () async => _real(),
        directory: () async => dir,
      );
      expect(
        await local.checkForUpdate(await local.current()),
        ContentUpdate.none,
      );
    });
  });
}
