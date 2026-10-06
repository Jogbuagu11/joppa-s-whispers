import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/content_repository.dart';

import '../support/content_fixtures.dart';

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
      loadBundled: () async => realContent(),
      remote: remote,
      directory: () async => dir,
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('ContentRepository', () {
    test('with nothing downloaded, plays the app\'s content', () async {
      expect((await repo.current()).version, 1);
    });

    test('a newer release is downloaded for the next launch', () async {
      remote.publish(realContent(version: 2));
      final current = await repo.current();
      expect(await repo.checkForUpdate(current), ContentUpdate.downloaded);
      // This launch keeps what it started with...
      expect(current.version, 1);
      // ...and the next launch gets the new content.
      expect((await repo.current()).version, 2);
    });

    test('nothing newer on the server: nothing downloaded', () async {
      remote.publish(realContent(version: 1));
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
        remote.publish(brokenContent(2));
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
        remote.publish(realContent(version: 2), asVersion: 3);
        expect(
          await repo.checkForUpdate(await repo.current()),
          ContentUpdate.rejected,
        );
      },
    );

    test('a release for a newer app is rejected', () async {
      remote.publish(realContent(version: 2, format: 2));
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

        cache().writeAsStringSync(jsonEncode(brokenContent(2).toJson()));
        expect((await repo.current()).version, 1);
        expect(cache().existsSync(), isFalse);
      },
    );

    test(
      'a release that passes the checks but will not load is rejected',
      () async {
        // The checks cannot foresee everything; the game must also really load it.
        final picky = ContentRepository(
          loadBundled: () async => realContent(),
          remote: remote,
          directory: () async => dir,
          trialLoad: (bundle) {
            if (bundle.version == 2) throw StateError('cannot load this');
          },
        );
        remote.publish(realContent(version: 2));
        expect(
          await picky.checkForUpdate(await picky.current()),
          ContentUpdate.rejected,
        );
        expect(cache().existsSync(), isFalse);
      },
    );

    test(
      'a saved download that no longer loads is dropped at launch',
      () async {
        // For example after an app update changed what the game can load.
        cache().writeAsStringSync(jsonEncode(realContent(version: 2).toJson()));
        final picky = ContentRepository(
          loadBundled: () async => realContent(),
          directory: () async => dir,
          trialLoad: (bundle) {
            if (bundle.version == 2) throw StateError('cannot load this');
          },
        );
        expect((await picky.current()).version, 1);
        expect(cache().existsSync(), isFalse);
        // And it stays gone: the next launch is clean too.
        expect((await picky.current()).version, 1);
      },
    );

    test('discardDownloaded removes the saved download', () async {
      cache().writeAsStringSync(jsonEncode(realContent(version: 2).toJson()));
      await repo.discardDownloaded();
      expect(cache().existsSync(), isFalse);
      expect((await repo.current()).version, 1);
    });

    test('an app update with newer content than the download wins', () async {
      cache().writeAsStringSync(jsonEncode(realContent(version: 2).toJson()));
      final newer = ContentRepository(
        loadBundled: () async => realContent(version: 3),
        directory: () async => dir,
      );
      expect((await newer.current()).version, 3);
      expect(cache().existsSync(), isFalse);
    });

    test('with no server configured, there is nothing to check', () async {
      final local = ContentRepository(
        loadBundled: () async => realContent(),
        directory: () async => dir,
      );
      expect(
        await local.checkForUpdate(await local.current()),
        ContentUpdate.none,
      );
    });
  });
}
