// Chooses and loads the content a play session runs on.
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/content_repository.dart';

final _log = Logger('SessionContent');

/// Loads downloaded content if it is newer and sound, else the app's own.
/// Downloaded content that will not load can never lock the game: it is
/// dropped for good and the content that shipped with the app is used.
Future<({ContentBundle bundle, ContentLoader loader})> loadSessionContent(
  ContentRepository repository,
) async {
  final bundle = await repository.current();
  try {
    return (bundle: bundle, loader: ContentLoader()..loadFromBundle(bundle));
  } on Object catch (e) {
    _log.severe('Content v${bundle.version} failed to load: $e');
    await repository.discardDownloaded();
    final bundled = await repository.loadBundled();
    return (bundle: bundled, loader: ContentLoader()..loadFromBundle(bundled));
  }
}
