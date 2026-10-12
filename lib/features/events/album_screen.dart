// The keepsake album: each set with its cards (found ones named, with
// their note; the rest still hidden) and the prize for finishing it.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/album.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';

/// The name of the album's record in the save file.
const albumRecord = 'album';

const _cream = Color(0xFFF3E5C8);

Future<void> showAlbum(
  BuildContext context, {
  required Album album,
  required AlbumState state,
  required Map<String, String> text,
  required String Function(PassReward reward) rewardWords,
}) => showDialog<void>(
  context: context,
  builder: (context) => GameDialog(
    key: const Key('album_popup'),
    icon: Icons.collections_bookmark,
    title: Text(
      text['title'] ?? '',
      style: const TextStyle(color: GamePalette.gold),
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final set in album.sets) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Text(
                  (text['set'] ?? '')
                      .replaceAll('{name}', set.name)
                      .replaceAll('{found}', '${state.found(set)}')
                      .replaceAll('{all}', '${set.cards.length}'),
                  key: Key('album_set_${set.id}'),
                  style: const TextStyle(
                    color: GamePalette.talents,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                (text['prize'] ?? '').replaceAll(
                  '{reward}',
                  rewardWords(set.reward),
                ),
                style: const TextStyle(color: GamePalette.muted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              for (final card in set.cards)
                _CardRow(
                  card: card,
                  count: state.cards[card.id] ?? 0,
                  unknown: text['unknown'] ?? '',
                ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      FilledButton(
        key: const Key('album_close'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(text['close'] ?? ''),
      ),
    ],
  ),
);

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.count,
    required this.unknown,
  });

  final AlbumCard card;
  final int count;
  final String unknown;

  @override
  Widget build(BuildContext context) {
    final found = count > 0;
    return Container(
      key: Key('album_card_${card.id}'),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: found ? GamePalette.panelLight : GamePalette.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GamePalette.panelEdge),
      ),
      child: Row(
        children: [
          Icon(
            found ? Icons.style : Icons.help_outline,
            color: found ? GamePalette.gold : GamePalette.muted,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  found ? card.name : unknown,
                  style: TextStyle(
                    color: found ? _cream : GamePalette.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (found)
                  Text(
                    card.note,
                    style: const TextStyle(
                      color: GamePalette.muted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (count > 1)
            Text(
              'x$count',
              style: const TextStyle(color: GamePalette.talents, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
