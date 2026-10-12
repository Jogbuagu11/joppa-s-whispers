// Checks content/study_guides.json. Pure Dart.

/// Words the study guides must carry.
const studyGuidesTextKeys = [
  'button',
  'title',
  'intro',
  'locked',
  'rumor',
  'verse',
  'questions',
  'copy',
  'copied',
  'footer',
];

/// Plain-English problems with the study guides; empty if they are sound.
/// [chapterIds] are the chapters the game has.
List<String> studyGuidesProblems(
  Object? json, {
  required Set<String> chapterIds,
}) {
  if (json is! Map<String, dynamic>) {
    return ['Study guides: the file is missing or has the wrong shape'];
  }
  final problems = <String>[];
  final guides = json['guides'];
  if (guides is! List<dynamic>) {
    problems.add('Study guides: "guides" must be a list');
  } else {
    final seen = <String>{};
    for (final guide in guides) {
      if (guide case {
        'chapter': final String chapter,
        'title': final String title,
        'rumor': final String rumor,
        'verse': final String verse,
        'ref': final String ref,
        'questions': final List<dynamic> questions,
      }) {
        final label = 'Study guide "$chapter"';
        if (!chapterIds.contains(chapter)) {
          problems.add('$label: there is no such chapter');
        }
        if (!seen.add(chapter)) {
          problems.add('$label: the chapter has two guides');
        }
        if (title.trim().isEmpty || title.length > 40) {
          problems.add('$label: title must be 1 to 40 letters');
        }
        if (rumor.trim().isEmpty || rumor.length > 240) {
          problems.add('$label: rumor must be 1 to 240 letters');
        }
        if (verse.trim().isEmpty || verse.length > 240) {
          problems.add('$label: verse must be 1 to 240 letters');
        }
        if (!ref.endsWith('(KJV)') && !ref.endsWith('(WEB)')) {
          problems.add('$label: the verse must name (KJV) or (WEB)');
        }
        if (questions.length != 3 ||
            questions.any(
              (q) => q is! String || q.trim().isEmpty || q.length > 200,
            )) {
          problems.add('$label: it needs 3 questions of up to 200 letters');
        }
      } else {
        problems.add(
          'Study guides: a guide needs chapter, title, rumor, verse, ref and '
          'questions',
        );
      }
    }
  }
  final text = json['text'];
  for (final key in studyGuidesTextKeys) {
    final words = text is Map<String, dynamic> ? text[key] : null;
    if (words is! String || words.isEmpty || words.length > 100) {
      problems.add(
        'Study guides: text "$key" is missing or longer than 100 letters',
      );
    }
  }
  return problems;
}

/// Every chapter id in the (already checked) chapters file.
Set<String> chapterIdsOf(Object? chaptersJson) => {
  if (chaptersJson case final List<dynamic> chapters)
    for (final chapter in chapters)
      if (chapter case {'id': final String id}) id,
};
