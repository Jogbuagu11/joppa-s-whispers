import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/features/offers/offer_confetti.dart';
import 'package:whispers_of_joppa/features/offers/offer_festive.dart';

void main() {
  final confetti = find.byKey(const Key('offer_confetti'));

  Future<void> show(WidgetTester tester, {bool lessMotion = false}) =>
      tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: lessMotion),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 360, height: 520, child: OfferConfetti()),
          ),
        ),
      );

  testWidgets('confetti falls once when the pop-up opens, then is gone', (
    tester,
  ) async {
    await show(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(confetti, findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(confetti, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('none for a player who has asked for less motion', (
    tester,
  ) async {
    await show(tester, lessMotion: true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(confetti, findsNothing);
  });

  testWidgets('the edge ornaments draw at any size without error', (
    tester,
  ) async {
    for (final size in const [Size(260, 300), Size(380, 640)]) {
      await tester.pumpWidget(
        Center(
          child: CustomPaint(size: size, painter: const OfferEdgePainter()),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
