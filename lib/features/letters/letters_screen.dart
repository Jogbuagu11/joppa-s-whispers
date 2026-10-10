// The keepsake book: every letter from Esther the player has found.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_app_bar.dart';
import 'package:whispers_of_joppa/domain/letters.dart';

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E6C8);
const _ink = Color(0xFF1A1205);
const _brown = Color(0xFF8A4B2A);

class LettersScreen extends StatelessWidget {
  const LettersScreen({
    super.key,
    required this.letters,
    required this.foundLetterIds,
    this.onOpened,
  });

  /// Told which letter the player opened (analytics).
  final void Function(String letterId)? onOpened;

  final List<LetterModel> letters;
  final Set<String> foundLetterIds;

  @override
  Widget build(BuildContext context) {
    final pages = keepsakePages(letters, foundLetterIds);
    final found = lettersFoundCount(letters, foundLetterIds);
    return Scaffold(
      key: const Key('letters_screen'),
      backgroundColor: _ink,
      appBar: gameAppBar(const Text("Esther's Letters")),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '$found of ${letters.length} found',
                key: const Key('letters_progress'),
                style: const TextStyle(color: _cream, fontSize: 14),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: pages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _LetterTile(
                  page: pages[i],
                  onOpen: () {
                    onOpened?.call(pages[i].letter.id);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LetterReader(letter: pages[i].letter),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.page, required this.onOpen});

  final LetterPage page;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final letter = page.letter;
    return Material(
      color: page.found ? _cream : const Color(0xFF2A1F08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('letter_tile_${letter.id}'),
        borderRadius: BorderRadius.circular(12),
        // A letter not found yet cannot be opened.
        onTap: page.found ? onOpen : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                page.found ? Icons.mail_outline : Icons.lock_outline,
                color: page.found ? _brown : const Color(0xFF6A5A3A),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.found ? letter.title : 'Not found yet',
                      key: Key('letter_title_${letter.id}'),
                      style: TextStyle(
                        color: page.found ? _ink : const Color(0xFF8A7A5A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chapter ${letter.chapter}',
                      style: TextStyle(
                        color: page.found ? _brown : const Color(0xFF6A5A3A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (page.found) const Icon(Icons.chevron_right, color: _brown),
            ],
          ),
        ),
      ),
    );
  }
}

/// One letter, shown in full on a parchment page.
class LetterReader extends StatelessWidget {
  const LetterReader({super.key, required this.letter});

  final LetterModel letter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('letter_reader'),
      backgroundColor: _ink,
      appBar: gameAppBar(Text(letter.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  letter.body,
                  key: const Key('letter_body'),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 17,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    letter.reference,
                    key: const Key('letter_reference'),
                    style: const TextStyle(
                      color: _brown,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
