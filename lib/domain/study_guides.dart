// Bible study guides (EXPANSION section 25): each finished chapter opens a
// short guide (the rumor, the verse, three questions) to share with a small
// group. Pure Dart, fully unit tested.

class StudyGuide {
  /// The chapter that opens it ("ch1").
  final String chapter;
  final String title;
  final String rumor;
  final String verse;

  /// Where the verse is from, with its translation ("John 7:24 (KJV)").
  final String ref;
  final List<String> questions;

  const StudyGuide({
    required this.chapter,
    required this.title,
    required this.rumor,
    required this.verse,
    required this.ref,
    required this.questions,
  });
}

/// The guides of content/study_guides.json, in order. (Check the file with
/// studyGuidesProblems first.) Empty if there are none (older content).
List<StudyGuide> studyGuidesFrom(Object? json) => [
  if (json case {'guides': final List<dynamic> guides})
    for (final guide in guides)
      if (guide case {
        'chapter': final String chapter,
        'title': final String title,
        'rumor': final String rumor,
        'verse': final String verse,
        'ref': final String ref,
        'questions': final List<dynamic> questions,
      })
        StudyGuide(
          chapter: chapter,
          title: title,
          rumor: rumor,
          verse: verse,
          ref: ref,
          questions: [
            for (final q in questions)
              if (q is String) q,
          ],
        ),
];

/// Whether [guide] is open: its chapter is one of [finished].
bool studyGuideOpen(StudyGuide guide, Iterable<String> finished) =>
    finished.contains(guide.chapter);

/// [guide] as plain words to paste to a group. [headings] are the words
/// for "rumor", "verse" and "questions"; [footer] says where it is from.
String studyGuideAsText(
  StudyGuide guide, {
  required String rumor,
  required String verse,
  required String questions,
  required String footer,
}) => [
  guide.title,
  '',
  '$rumor: ${guide.rumor}',
  '',
  '$verse: "${guide.verse}" ${guide.ref}',
  '',
  '$questions:',
  for (final (i, q) in guide.questions.indexed) '${i + 1}. $q',
  if (footer.isNotEmpty) ...['', footer],
].join('\n');

/// The words of content/study_guides.json.
Map<String, String> studyGuidesText(Object? json) => {
  if (json case {'text': final Map<String, dynamic> text})
    for (final e in text.entries)
      if (e.value case final String words) e.key: words,
};
