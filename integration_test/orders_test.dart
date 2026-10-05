// Milestone 7: order cards show, and delivering one takes the items and pays.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/main.dart' as app;

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delivering an order removes items and pays rewards', (
    tester,
  ) async {
    app.main();
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));

    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final economy = await _content('economy') as Map<String, dynamic>;
    final start = await _content('starting_board') as Map<String, dynamic>;
    final slots = economy['order_slots'] as int;

    // What the board starts with.
    final onBoard = <String, int>{};
    for (final i in start['items'] as List<dynamic>) {
      final id = (i as Map<String, dynamic>)['item_id'] as String;
      onBoard[id] = (onBoard[id] ?? 0) + 1;
    }

    // Every visible order has a card.
    final visible = orders.take(slots).toList();
    for (final order in visible) {
      expect(find.byKey(Key('order_card_${order['id']}')), findsOneWidget);
    }
    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';
    expect(text('talents_count'), '0');
    expect(text('blessings_count'), '0');

    // Find a visible order the starting board can already fill.
    bool fillable(Map<String, dynamic> order) =>
        (order['items'] as List<dynamic>).every((i) {
          final item = i as Map<String, dynamic>;
          return (onBoard[item['item_id']] ?? 0) >= (item['count'] as int);
        });
    final ready = visible.where(fillable).toList();
    expect(ready, isNotEmpty, reason: 'starting board should fill one order');
    final order = ready.first;
    final id = order['id'] as String;
    final wanted =
        (order['items'] as List<dynamic>).first as Map<String, dynamic>;
    final rewards = order['rewards'] as Map<String, dynamic>;

    // An order the board cannot fill has a disabled Deliver button.
    final notReady = visible.where((o) => !fillable(o)).toList();
    if (notReady.isNotEmpty) {
      final button = tester.widget<FilledButton>(
        find.byKey(Key('order_deliver_${notReady.first['id']}')),
      );
      expect(button.onPressed, isNull);
    }

    await tester.tap(find.byKey(Key('order_deliver_$id')));
    await tester.pump(const Duration(milliseconds: 500));

    // Rewards are paid, the card is replaced by the next order in line.
    expect(text('talents_count'), '${rewards['talents']}');
    expect(text('blessings_count'), '${rewards['blessings']}');
    expect(find.byKey(Key('order_card_$id')), findsNothing);
    if (orders.length > slots) {
      expect(
        find.byKey(Key('order_card_${orders[slots]['id']}')),
        findsOneWidget,
      );
    }

    // The delivered items left the board: another order wanting the same item
    // now shows fewer in hand than before.
    final sameItem = orders
        .skip(slots)
        .take(1)
        .where(
          (o) => (o['items'] as List<dynamic>).any(
            (i) => (i as Map<String, dynamic>)['item_id'] == wanted['item_id'],
          ),
        );
    for (final next in sameItem) {
      final left = (onBoard[wanted['item_id']] ?? 0) - (wanted['count'] as int);
      final need =
          ((next['items'] as List<dynamic>).firstWhere(
                    (i) =>
                        (i as Map<String, dynamic>)['item_id'] ==
                        wanted['item_id'],
                  )
                  as Map<String, dynamic>)['count']
              as int;
      expect(
        text('order_have_${next['id']}_${wanted['item_id']}'),
        '${left.clamp(0, need)}/$need',
      );
    }
  });
}
