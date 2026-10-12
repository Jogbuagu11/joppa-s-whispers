// The study guides: one for each chapter, open once the chapter is
// finished, with a button that copies it to paste to a small group.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whispers_of_joppa/app/game_app_bar.dart';
import 'package:whispers_of_joppa/domain/study_guides.dart';

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E6C8);
const _ink = Color(0xFF1A1205);
const _brown = Color(0xFF8A4B2A);

class StudyGuidesScreen extends StatelessWidget {
  const StudyGuidesScreen({
    super.key,
    required this.guides,
    required this.finished,
    required this.text,
  });

  final List<StudyGuide> guides;

  /// The chapters the player has finished.
  final Set<String> finished;
  final Map<String, String> text;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('study_guides_screen'),
    backgroundColor: _ink,
    appBar: gameAppBar(Text(text['title'] ?? '')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              text['intro'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _cream, fontSize: 14),
            ),
          ),
          for (final guide in guides)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: studyGuideOpen(guide, finished)
                  ? _GuideCard(guide: guide, text: text)
                  : _LockedCard(guide: guide, words: text['locked'] ?? ''),
            ),
        ],
      ),
    ),
  );
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.guide, required this.words});

  final StudyGuide guide;
  final String words;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('study_locked_${guide.chapter}'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF2A1F08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.lock, color: _brown),
        const SizedBox(width: 10),
        Expanded(
          child: Text(words, style: const TextStyle(color: _cream)),
        ),
      ],
    ),
  );
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide, required this.text});

  final StudyGuide guide;
  final Map<String, String> text;

  @override
  Widget build(BuildContext context) {
    Widget heading(String key) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(
        text[key] ?? '',
        style: const TextStyle(
          color: _brown,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
    const body = TextStyle(color: _ink, fontSize: 15, height: 1.3);
    return Container(
      key: Key('study_guide_${guide.chapter}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guide.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          heading('rumor'),
          Text(guide.rumor, style: body),
          heading('verse'),
          Text(
            '"${guide.verse}"\n${guide.ref}',
            style: body.copyWith(fontStyle: FontStyle.italic),
          ),
          heading('questions'),
          for (final (i, q) in guide.questions.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${i + 1}. $q', style: body),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: Key('study_copy_${guide.chapter}'),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
              ),
              icon: const Icon(Icons.copy, size: 18),
              label: Text(text['copy'] ?? ''),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: studyGuideAsText(
                      guide,
                      rumor: text['rumor'] ?? '',
                      verse: text['verse'] ?? '',
                      questions: text['questions'] ?? '',
                      footer: text['footer'] ?? '',
                    ),
                  ),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      key: const Key('study_copied'),
                      content: Text(text['copied'] ?? ''),
                    ),
                  );
              },
            ),
          ),
        ],
      ),
    );
  }
}
