// The message shown when a chapter's last task is done.
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/progression.dart';

const _gold = Color(0xFFD4802A);

Future<void> showChapterEnding(BuildContext context, ChapterEnding ending) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => GameDialog(
      key: const Key('chapter_ending'),
      icon: Icons.menu_book,
      title: Text(
        ending.title,
        key: const Key('chapter_ending_title'),
        style: const TextStyle(color: _gold),
      ),
      content: Text(
        ending.body,
        key: const Key('chapter_ending_body'),
        style: const TextStyle(color: Colors.white, height: 1.35),
      ),
      actions: [
        FilledButton(
          key: const Key('chapter_ending_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ending.button),
        ),
      ],
    ),
  );
}
