// All game content as one unit: what ships in the app, and what the server
// can replace it with. Pure Dart so tool/ scripts can use it.
import 'package:whispers_of_joppa/data/content_validator.dart';

/// The content format this build understands. A bundle with a higher format
/// was made for a newer app and is ignored.
// Format 2: orders wait for their chapter, and a generator on the starting
// board may name the chapter it arrives in. An older app cannot play that.
// Format 3: generators have kinds (charged, free, temporary) and may wait
// for a player level; some chains have no generator; items can be used.
const supportedContentFormat = 3;

/// Every content file (`content/<name>.json`) a bundle must contain.
const contentFileNames = [
  'chains',
  'generators',
  'economy',
  'starting_board',
  'orders',
  'characters',
  'scenes',
  'chapters',
  'locations',
  'letters',
  'tutorial',
  'endings',
  'products',
  'notifications',
  'levels',
  'board_text',
];

class ContentBundle {
  /// Rises by one with every content release.
  final int version;
  final int format;

  /// File name (without .json) -> its decoded JSON.
  final Map<String, Object?> files;

  const ContentBundle({
    required this.version,
    required this.format,
    required this.files,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'format': format,
    'files': files,
  };

  /// Throws [FormatException] if [json] is not shaped like a bundle.
  factory ContentBundle.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final format = json['format'];
    final files = json['files'];
    if (version is! int || format is! int || files is! Map<String, dynamic>) {
      throw const FormatException('Not a content bundle');
    }
    return ContentBundle(version: version, format: format, files: files);
  }

  /// Plain-English problems that make this bundle unusable; empty if it is
  /// safe to play with.
  List<String> problems() {
    if (version < 1) return ['Content version must be 1 or more'];
    if (format > supportedContentFormat) {
      return ['Content format $format needs a newer version of the app'];
    }
    final missing = [
      for (final name in contentFileNames)
        if (!files.containsKey(name)) 'Content file "$name" is missing',
    ];
    if (missing.isNotEmpty) return missing;
    // Levels came later than the other files: an empty one must not pass.
    if (files['levels'] == null) return ['Content file "levels" is empty'];
    final wording = boardTextProblems(files['board_text']);
    if (wording.isNotEmpty) return wording;
    return validateContent(
      chainsJson: files['chains'],
      generatorsJson: files['generators'],
      economyJson: files['economy'],
      startingBoardJson: files['starting_board'],
      ordersJson: files['orders'],
      charactersJson: files['characters'],
      scenesJson: files['scenes'],
      chaptersJson: files['chapters'],
      locationsJson: files['locations'],
      lettersJson: files['letters'],
      tutorialJson: files['tutorial'],
      endingsJson: files['endings'],
      productsJson: files['products'],
      notificationsJson: files['notifications'],
      levelsJson: files['levels'],
    );
  }
}

/// Which content to start the game with: the downloaded copy only if it is
/// newer than what shipped in the app and has no problems.
ContentBundle chooseContent({
  required ContentBundle bundled,
  required ContentBundle? cached,
}) {
  if (cached == null) return bundled;
  if (cached.version <= bundled.version) return bundled;
  return cached.problems().isEmpty ? cached : bundled;
}

/// The small wording used on the board (content/board_text.json).
const boardTextKeys = [
  'use_manna',
  'use',
  'keep',
  'hourglass_hint',
  'ok',
  // Not words: the picture behind everything above the board.
  'header_background',
];

/// Plain-English problems with the board wording; empty if it is sound.
List<String> boardTextProblems(Object? json) => [
  if (json is! Map<String, dynamic>)
    'Board text: the file is missing or has the wrong shape'
  else
    for (final key in boardTextKeys)
      if (json[key] is! String ||
          (json[key] as String).isEmpty ||
          (json[key] as String).length > 80)
        'Board text: "$key" is missing or longer than 80 letters',
];
