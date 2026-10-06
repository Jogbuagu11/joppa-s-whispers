// Esther's letters — pure Dart, fully unit tested.

/// One letter, loaded from content/letters.json.
class LetterModel {
  final String id;
  final int chapter;
  final String title;
  final String body;
  final String reference;

  const LetterModel({
    required this.id,
    required this.chapter,
    required this.title,
    required this.body,
    required this.reference,
  });

  factory LetterModel.fromJson(Map<String, dynamic> json) => LetterModel(
    id: json['id'] as String,
    chapter: json['chapter'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
    reference: json['reference'] as String,
  );
}

/// A page of the keepsake book: a letter, and whether it has been found yet.
class LetterPage {
  final LetterModel letter;
  final bool found;

  const LetterPage(this.letter, {required this.found});
}

/// Every letter in book order (by chapter, then as listed in content), each
/// marked found or not. Unfound letters keep their place as blank pages.
List<LetterPage> keepsakePages(
  List<LetterModel> letters,
  Set<String> foundLetterIds,
) {
  final ordered = [...letters];
  // A stable sort by chapter keeps the content order within a chapter.
  final position = {for (int i = 0; i < letters.length; i++) letters[i].id: i};
  ordered.sort((a, b) {
    final byChapter = a.chapter.compareTo(b.chapter);
    if (byChapter != 0) return byChapter;
    return (position[a.id] ?? 0).compareTo(position[b.id] ?? 0);
  });
  return [
    for (final letter in ordered)
      LetterPage(letter, found: foundLetterIds.contains(letter.id)),
  ];
}

/// How many of [letters] have been found.
int lettersFoundCount(List<LetterModel> letters, Set<String> foundLetterIds) =>
    letters.where((l) => foundLetterIds.contains(l.id)).length;
