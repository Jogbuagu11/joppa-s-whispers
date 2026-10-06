// Decides which content the game runs on, and fetches newer content from the
// server in the background. A bad download can never break the game: it is
// checked before it is kept, and the app's own content is always the fallback.
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';

final _log = Logger('Content');

/// Where newer content comes from (Supabase in the app, a fake in tests).
abstract class RemoteContent {
  /// The newest release's version and where to download it, or null if none.
  Future<({int version, String path})?> latest();

  /// The bundle file at [path], as text.
  Future<String> download(String path);
}

/// What a check for newer content did.
enum ContentUpdate { none, downloaded, rejected, failed }

class ContentRepository {
  /// Reads the content that shipped inside the app.
  final Future<ContentBundle> Function() loadBundled;
  final RemoteContent? remote;

  /// Builds the game's tables from a bundle, throwing if it cannot. Used to
  /// prove a downloaded bundle really loads, beyond passing the content
  /// checks, before it is ever trusted.
  final void Function(ContentBundle bundle) trialLoad;
  final Future<Directory> Function() _directory;

  ContentRepository({
    required this.loadBundled,
    this.remote,
    void Function(ContentBundle bundle)? trialLoad,
    Future<Directory> Function()? directory,
  }) : trialLoad =
           trialLoad ?? ((bundle) => ContentLoader().loadFromBundle(bundle)),
       _directory = directory ?? getApplicationDocumentsDirectory;

  Future<File> _cacheFile() async =>
      File('${(await _directory()).path}/content_cache.json');

  /// The content to play with now. Never throws for a bad download: it falls
  /// back to the app's own content and removes the bad file.
  Future<ContentBundle> current() async {
    final bundled = await loadBundled();
    final cached = await _readCache();
    var chosen = chooseContent(bundled: bundled, cached: cached);
    if (identical(chosen, cached) && !_loads(chosen)) chosen = bundled;
    if (cached != null && !identical(chosen, cached)) {
      _log.info('Discarding downloaded content v${cached.version}');
      await _deleteCache();
    }
    _log.info('Using content v${chosen.version}');
    return chosen;
  }

  /// Looks for content newer than [current]. If there is some and it passes
  /// every check, it is kept for the NEXT launch (content never changes
  /// under a game in progress). Never throws.
  Future<ContentUpdate> checkForUpdate(ContentBundle current) async {
    final source = remote;
    if (source == null) return ContentUpdate.none;
    try {
      final latest = await source.latest();
      if (latest == null || latest.version <= current.version) {
        return ContentUpdate.none;
      }
      final text = await source.download(latest.path);
      final bundle = ContentBundle.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );
      final problems = [
        if (bundle.version != latest.version)
          'Bundle says v${bundle.version} but was released as v${latest.version}',
        ...bundle.problems(),
      ];
      if (problems.isEmpty && !_loads(bundle)) {
        problems.add('It passes the checks but the game cannot load it');
      }
      if (problems.isNotEmpty) {
        _log.severe(
          'Server content v${latest.version} rejected: ${problems.take(5).join('; ')}',
        );
        return ContentUpdate.rejected;
      }
      final file = await _cacheFile();
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(text, flush: true);
      await temp.rename(file.path);
      _log.info('Downloaded content v${bundle.version} for next launch');
      return ContentUpdate.downloaded;
    } on Object catch (e, stack) {
      // No connection, a damaged file, a wrong shape: keep what we have.
      _log.warning('Content update check failed', e, stack);
      return ContentUpdate.failed;
    }
  }

  /// Removes downloaded content so the next launch uses the app's own. Called
  /// if the game fails to start on downloaded content.
  Future<void> discardDownloaded() => _deleteCache();

  /// Whether the game can really build its tables from [bundle].
  bool _loads(ContentBundle bundle) {
    try {
      trialLoad(bundle);
      return true;
    } on Object catch (e) {
      // Any failure at all means this content must not be used.
      _log.severe('Content v${bundle.version} does not load: $e');
      return false;
    }
  }

  Future<ContentBundle?> _readCache() async {
    final file = await _cacheFile();
    if (!file.existsSync()) return null;
    try {
      return ContentBundle.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } on Object catch (e) {
      _log.warning('Downloaded content could not be read: $e');
      await _deleteCache();
      return null;
    }
  }

  Future<void> _deleteCache() async {
    final file = await _cacheFile();
    if (file.existsSync()) await file.delete();
  }
}
