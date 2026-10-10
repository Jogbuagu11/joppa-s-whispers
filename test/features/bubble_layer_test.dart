import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/bubbles.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/features/bubbles/bubble_controller.dart';
import 'package:whispers_of_joppa/features/bubbles/bubble_layer.dart';

const _b2 = ItemModel(
  itemId: 'b2',
  chainId: 'bakery',
  tier: 2,
  name: 'Flour',
  asset: '',
);

void main() {
  testWidgets('each bubble is drawn at the corner of its cell, says what it '
      'holds, and reports a tap; a popped one is gone', (tester) async {
    final semantics = tester.ensureSemantics();
    var now = DateTime(2026, 10, 10, 12);
    final tapped = <int>[];
    final bubbles = BubbleController(
      rules: const BubbleRules(
        chance: 1,
        higherChance: 0,
        seconds: 60,
        pearlsPerTier: 2,
        adMaxTier: 2,
        talentsPerTier: 3,
        maxAtOnce: 2,
      ),
      items: const {'b2': _b2},
      chains: const {},
      allowed: () => true,
      addTalents: (_) {},
      spendPearls: (_) => true,
      giveItem: (_) {},
      clock: () => now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 350,
            height: 450,
            child: BubbleLayer(
              controller: bubbles,
              cellRect: (col, row) =>
                  Rect.fromLTWH(col * 50.0, row * 50.0, 50, 50),
              placeholderColors: const {'bakery': 0xFF885522},
              onTap: (b) => tapped.add(b.id),
              label: 'Bubble with {name}',
            ),
          ),
        ),
      ),
    );
    expect(find.byType(GestureDetector), findsNothing);

    bubbles.afterMerge(_b2, col: 2, row: 3);
    await tester.pump();
    final id = bubbles.bubbles.single.id;
    final where = tester.getRect(find.byKey(Key('bubble_$id')));
    // Smaller than the cell, over its top right corner.
    expect(where.width, lessThan(50));
    expect(where.center.dx, greaterThan(125));
    expect(where.center.dy, lessThan(175));
    expect(find.bySemanticsLabel(RegExp('Bubble with Flour')), findsOneWidget);
    // No art yet: the tier number stands in.
    expect(find.text('2'), findsOneWidget);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 1);

    await tester.tap(find.byKey(Key('bubble_$id')));
    expect(tapped, [id]);

    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      closeTo(0.5, 0.02),
    );
    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(find.byKey(Key('bubble_$id')), findsNothing);
    bubbles.dispose();
    semantics.dispose();
  });
}
