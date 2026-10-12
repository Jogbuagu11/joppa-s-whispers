// A delivered order now and then brings a keepsake card.
import 'dart:math';

import 'package:whispers_of_joppa/domain/album.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/album_screen.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

/// Draws for a card after a delivered order. If one comes it is put in the
/// album ([extras]), any set it finishes is paid through [grant] (once),
/// and the words to tell the player are returned; null if no card came.
String? albumCardOnOrder({
  required Album album,
  required SaveExtras extras,
  required Random random,
  required void Function(PassReward reward) grant,
  required Map<String, String> text,
  required String Function(PassReward reward) rewardWords,
}) {
  final before = AlbumState.fromJson(extras.read(albumRecord));
  final card = albumCardFor(
    album,
    before,
    chance: random.nextInt(100),
    pick: random.nextInt(1 << 20),
  );
  if (card == null) return null;
  final after = albumAfterCard(album, before, card);
  // Recorded before any prize is handed over.
  extras.write(albumRecord, after.state.toJson());
  for (final set in after.finished) {
    grant(set.reward);
  }
  return [
    (text[before.has(card.id) ? 'spare' : 'found'] ?? '').replaceAll(
      '{name}',
      card.name,
    ),
    for (final set in after.finished)
      (text['finished'] ?? '')
          .replaceAll('{name}', set.name)
          .replaceAll('{reward}', rewardWords(set.reward)),
  ].join('\n');
}
