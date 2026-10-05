import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/locations.dart';
import 'package:whispers_of_joppa/features/restoration/location_screen.dart';

LocationModel _location(int areas) => LocationModel(
  id: 'bakehouse',
  name: "Esther's Bakehouse",
  areas: [
    for (int i = 1; i <= areas; i++)
      AreaModel(
        id: 'area_$i',
        name: 'A rather long area name $i',
        before: 'loc_area_${i}_before',
        after: 'loc_area_${i}_after',
      ),
  ],
);

Future<void> _show(
  WidgetTester tester, {
  required Set<String> restored,
  Set<String> assets = const {},
  String? justRestored,
}) async {
  // A small phone (iPhone SE size).
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: LocationScreen(
        location: _location(7),
        restoredAreaIds: restored,
        availableAssets: assets,
        justRestoredAreaId: justRestored,
      ),
    ),
  );
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

void main() {
  testWidgets('fits a small phone and shows every area', (tester) async {
    await _show(tester, restored: {'area_2'});
    expect(tester.takeException(), isNull);
    expect(_text(tester, 'location_progress'), '1 of 7 restored');
    for (int i = 1; i <= 7; i++) {
      expect(find.byKey(Key('area_area_$i')), findsOneWidget);
    }
    expect(_text(tester, 'area_state_area_2'), 'Restored');
    expect(_text(tester, 'area_state_area_1'), 'Not yet');
    expect(find.byKey(const ValueKey('loc_area_2_after')), findsOneWidget);
    expect(find.byKey(const ValueKey('loc_area_1_before')), findsOneWidget);
  });

  testWidgets('a delivered picture fills its card', (tester) async {
    await _show(
      tester,
      restored: const {},
      assets: {'assets/locations/loc_area_1_before.png'},
    );
    // The file does not really exist in the test bundle, so the picture falls
    // back to the placeholder without throwing; what matters is the box size.
    await tester.pump();
    expect(tester.takeException(), isNull);
    final card = tester.getSize(find.byKey(const Key('area_area_1')));
    final picture = tester.getSize(
      find.byKey(const ValueKey('loc_area_1_before')),
    );
    expect(picture.width, closeTo(card.width, 4));
    expect(picture.height, greaterThan(card.height * 0.6));
  });

  testWidgets('a just-restored area changes in front of the player', (
    tester,
  ) async {
    await _show(tester, restored: {'area_3'}, justRestored: 'area_3');
    expect(_text(tester, 'area_state_area_3'), 'Not yet');
    expect(_text(tester, 'location_progress'), '0 of 7 restored');
    expect(find.byKey(const ValueKey('loc_area_3_before')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(seconds: 1));
    expect(_text(tester, 'area_state_area_3'), 'Restored');
    expect(_text(tester, 'location_progress'), '1 of 7 restored');
    expect(find.byKey(const ValueKey('loc_area_3_after')), findsOneWidget);
    expect(find.byKey(const ValueKey('loc_area_3_before')), findsNothing);
  });
}
