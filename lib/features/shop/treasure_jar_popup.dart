// The Treasure Jar's pop-up: how full it is, what opening it gives, the
// store's own price on one button, and always a clear way to say no.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/domain/treasure_jar.dart';
import 'package:whispers_of_joppa/features/shop/treasure_jar_picture.dart';

/// Shows the jar. [price] is the store's price for opening it, or null if
/// the store could not be asked. [state] is read afresh as the pop-up is
/// rebuilt, so a jar opened while it is up is shown empty at once.
/// Returns whether the player asked to open it.
Future<bool> showTreasureJar(
  BuildContext context, {
  required TreasureJarRules rules,
  required TreasureJarState Function() state,
  required Listenable changes,
  required Map<String, String> text,
  required PurchaseCoordinator? shop,
  required String? price,
  void Function(String productId)? onBuy,
}) async {
  shop?.message.value = null;
  var asked = false;
  await showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: Listenable.merge([changes, shop?.busy, shop?.message]),
      builder: (context, _) {
        final jar = state();
        final size = rules.sizeAfter(jar.opened);
        final full = jarIsFull(rules, jar);
        final signedIn = shop?.backend.signedIn ?? false;
        final busy = shop?.busy.value ?? false;
        final message =
            shop?.message.value ??
            (!full
                ? null
                : !signedIn
                ? text['sign_in']
                : price == null
                ? text['unavailable']
                : null);
        return GameDialog(
          key: const Key('treasure_jar_popup'),
          icon: Icons.savings,
          title: Text(
            text['title'] ?? '',
            style: const TextStyle(color: GamePalette.gold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TreasureJarPicture(fill: jar.saved / size.pearls),
              const SizedBox(height: 8),
              Text(
                (text['count'] ?? '')
                    .replaceAll('{saved}', '${jar.saved}')
                    .replaceAll('{pearls}', '${size.pearls}'),
                key: const Key('treasure_jar_count'),
                style: const TextStyle(
                  color: GamePalette.pearls,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (jar.saved / size.pearls).clamp(0, 1).toDouble(),
                  minHeight: 10,
                  backgroundColor: GamePalette.panelLight,
                  color: GamePalette.offerPearls,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                text[full ? 'full' : 'filling'] ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFF3E5C8)),
              ),
              const SizedBox(height: 6),
              Text(
                text['next'] ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: GamePalette.muted, fontSize: 12),
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(
                  message,
                  key: const Key('treasure_jar_message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: GamePalette.manna),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              key: const Key('treasure_jar_close'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                text['close'] ?? '',
                style: const TextStyle(color: Color(0xFFF3E5C8)),
              ),
            ),
            FilledButton(
              key: const Key('treasure_jar_open'),
              // Only a full jar can be opened, by a signed-in player (a
              // purchase belongs to an account), at a price the store gave.
              onPressed:
                  full && signedIn && price != null && !busy && shop != null
                  ? () {
                      asked = true;
                      onBuy?.call(size.productId);
                      shop.buy(size.productId);
                    }
                  : null,
              child: Text(
                full && price != null
                    ? (text['open'] ?? '').replaceAll('{price}', price)
                    : text[full ? 'title' : 'not_full'] ?? '',
              ),
            ),
          ],
        );
      },
    ),
  );
  return asked;
}
