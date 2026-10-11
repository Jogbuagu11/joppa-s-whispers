// The season pass pop-up: every milestone with its free and its Premium
// reward, what Premium Plus adds, the store's own prices, and always a
// clear way to say no.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/event_controller.dart';
import 'package:whispers_of_joppa/features/events/event_pass.dart';

const _cream = Color(0xFFF3E5C8);

/// Shows the pass of [controller]'s event. [prices] are the store's (empty
/// if it could not be asked).
Future<void> showSeasonPass(
  BuildContext context, {
  required EventController controller,
  required EventPass pass,
  required Map<String, String> prices,
}) {
  pass.shop?.message.value = null;
  return showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        pass.changes,
        pass.shop?.busy,
        pass.shop?.message,
      ]),
      builder: (context, _) =>
          _PassDialog(controller: controller, pass: pass, prices: prices),
    ),
  );
}

class _PassDialog extends StatelessWidget {
  const _PassDialog({
    required this.controller,
    required this.pass,
    required this.prices,
  });

  final EventController controller;
  final EventPass pass;
  final Map<String, String> prices;

  String _t(String key) => pass.text[key] ?? '';

  @override
  Widget build(BuildContext context) {
    final event = controller.event;
    final rules = event.pass;
    final tier = controller.tier();
    final shop = pass.shop;
    final signedIn = shop?.backend.signedIn ?? false;
    final premiumPrice = prices[pass.premiumProduct];
    final plusPrice = prices[pass.plusProduct];
    // A payment still on its way is never asked for a second time.
    final waiting =
        shop == null ||
        shop.busy.value ||
        shop.isWaitingFor(pass.premiumProduct) ||
        shop.isWaitingFor(pass.plusProduct);
    VoidCallback? buy(String productId, String? price) {
      if (shop == null || price == null || waiting || !signedIn) return null;
      // Not for an event that is over: the pass would be worth nothing.
      if (!controller.isLive) return null;
      return () {
        pass.onBuy?.call(productId);
        // The server is told which event's pass is on the screen, in case
        // the game is closed before the payment comes back.
        shop.backend.noteOffer(
          offerId: event.id,
          productId: productId,
          outcome: 'shown',
        );
        // The event goes with the purchase: the pass is for it alone.
        shop.buy(productId, offerId: event.id);
      };
    }

    final message =
        shop?.message.value ??
        (tier == PassTier.plus
            ? null
            : !signedIn
            ? _t('sign_in')
            : premiumPrice == null
            ? _t('unavailable')
            : null);
    return GameDialog(
      key: const Key('season_pass_popup'),
      icon: Icons.workspace_premium,
      title: Text(_t('title'), style: const TextStyle(color: GamePalette.gold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t(switch (tier) {
                PassTier.free => 'have_free',
                PassTier.premium => 'have_premium',
                PassTier.plus => 'have_plus',
              }),
              key: const Key('season_pass_tier'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: GamePalette.talents,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: ListView(
                children: [
                  for (var i = 0; i < event.milestones.length; i++)
                    _PassRow(
                      index: i,
                      points: _t(
                        'at_points',
                      ).replaceAll('{points}', '${event.milestones[i].points}'),
                      free: pass.words(
                        PassReward(
                          manna: event.milestones[i].manna,
                          talents: event.milestones[i].talents,
                        ),
                      ),
                      premium: rules != null && i < rules.premium.length
                          ? pass.words(rules.premium[i])
                          : '',
                      freePaid: i < controller.paid,
                      premiumPaid: i < controller.premiumPaid,
                      locked: tier == PassTier.free,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t('premium_note'),
              style: const TextStyle(color: _cream, fontSize: 12),
            ),
            if (rules != null && rules.plusBonusPercent > 0) ...[
              const SizedBox(height: 4),
              Text(
                _t(
                  'plus_note',
                ).replaceAll('{percent}', '${rules.plusBonusPercent}'),
                style: const TextStyle(color: _cream, fontSize: 12),
              ),
            ],
            if (rules != null && rules.endlessEvery > 0) ...[
              const SizedBox(height: 4),
              Text(
                _t('endless')
                    .replaceAll('{reward}', pass.words(rules.endless))
                    .replaceAll('{points}', '${rules.endlessEvery}'),
                key: const Key('season_pass_endless'),
                style: const TextStyle(color: GamePalette.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _t('this_event'),
              style: const TextStyle(color: GamePalette.muted, fontSize: 12),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                key: const Key('season_pass_message'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: GamePalette.manna),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('season_pass_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t('close'), style: const TextStyle(color: _cream)),
        ),
        if (tier == PassTier.free)
          OutlinedButton(
            key: const Key('season_pass_buy_premium'),
            onPressed: buy(pass.premiumProduct, premiumPrice),
            style: OutlinedButton.styleFrom(
              foregroundColor: GamePalette.talents,
            ),
            child: Text(
              _t('buy_premium').replaceAll('{price}', premiumPrice ?? ''),
            ),
          ),
        if (tier == PassTier.free)
          FilledButton(
            key: const Key('season_pass_buy_plus'),
            onPressed: buy(pass.plusProduct, plusPrice),
            child: Text(_t('buy_plus').replaceAll('{price}', plusPrice ?? '')),
          ),
        // Premium again is the difference in price: it makes Plus.
        if (tier == PassTier.premium)
          FilledButton(
            key: const Key('season_pass_upgrade'),
            onPressed: buy(pass.premiumProduct, premiumPrice),
            child: Text(
              _t('upgrade').replaceAll('{price}', premiumPrice ?? ''),
            ),
          ),
      ],
    );
  }
}

class _PassRow extends StatelessWidget {
  const _PassRow({
    required this.index,
    required this.points,
    required this.free,
    required this.premium,
    required this.freePaid,
    required this.premiumPaid,
    required this.locked,
  });

  final int index;
  final String points;
  final String free;
  final String premium;
  final bool freePaid;
  final bool premiumPaid;
  final bool locked;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          points,
          style: const TextStyle(color: GamePalette.muted, fontSize: 11),
        ),
        Row(
          children: [
            Icon(
              freePaid ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: freePaid ? GamePalette.ready : GamePalette.muted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                free,
                style: const TextStyle(color: _cream, fontSize: 13),
              ),
            ),
            Icon(
              premiumPaid
                  ? Icons.check_circle
                  : (locked ? Icons.lock : Icons.workspace_premium),
              size: 14,
              color: premiumPaid ? GamePalette.ready : GamePalette.talents,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                premium,
                key: Key('season_pass_premium_$index'),
                style: const TextStyle(
                  color: GamePalette.talents,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
