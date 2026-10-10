// Milestone 18: out of Manna, the player may choose to watch an ad for more.
// The ad here is a stand-in: no real ad is ever loaded by a test.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/ad_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an ad the player chooses to watch gives bonus Manna', (
    tester,
  ) async {
    const manna = 0;
    final ads = FakeAdService();
    await SaveRepository().clear();
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          startingMannaOverride: manna,
          playOpeningScene: false,
          playTutorial: false,
          ads: ads,
        ),
      ),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));

    final start =
        jsonDecode(await rootBundle.loadString('content/starting_board.json'))
            as Map<String, dynamic>;
    final economy =
        jsonDecode(await rootBundle.loadString('content/economy.json'))
            as Map<String, dynamic>;
    final max = economy['max_manna'] as int;
    final cost = economy['generator_tap_cost'] as int;
    final generator =
        (start['generators'] as List<dynamic>).first as Map<String, dynamic>;

    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    final generatorCentre = Offset(
      rect.left +
          (rect.width - BoardGame.cols * cell) / 2 +
          ((generator['col'] as int) + 0.5) * cell,
      rect.top +
          (rect.height - BoardGame.rows * cell) / 2 +
          ((generator['row'] as int) + 0.5) * cell,
    );
    String countText() =>
        tester.widget<Text>(find.byKey(const Key('manna_count'))).data ?? '';

    final bonus = economy['rewarded_ad_manna_bonus'] as int;
    final cap = economy['rewarded_ad_manna_daily_cap'] as int;
    expect(cost, greaterThan(0));
    final watchAd = find.byKey(const Key('out_of_manna_watch_ad'));

    // No Manna: tapping a generator brings up the popup, with the ad choice.
    await tester.tapAt(generatorCentre);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('out_of_manna_popup')), findsOneWidget);
    expect(watchAd, findsOneWidget);
    // Nothing plays until the player asks.
    expect(ads.shown, 0);

    // An ad closed early gives nothing.
    ads.watchedToEnd = false;
    await tester.tap(watchAd);
    await tester.pump(const Duration(milliseconds: 600));
    expect(ads.shown, 1);
    expect(countText(), '0/$max');

    // An ad watched to the end gives the bonus.
    ads.watchedToEnd = true;
    await tester.tap(watchAd);
    await tester.pump(const Duration(milliseconds: 600));
    expect(countText(), '$bonus/$max');

    // Watching up to the daily limit removes the choice.
    for (int i = 1; i < cap; i++) {
      await tester.tap(watchAd);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(countText(), '${bonus * cap}/$max');
    expect(watchAd, findsNothing);

    // The popup can always simply be closed.
    await tester.tap(find.byKey(const Key('out_of_manna_ok')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('out_of_manna_popup')), findsNothing);
  });

  testWidgets('the banner sits under the board after the tutorial, and the '
      'board is still there', (tester) async {
    final ads = FakeAdService()
      ..fakeBanner = const ColoredBox(
        key: Key('fake_banner'),
        color: Color(0xFF445566),
        child: SizedBox(width: 320, height: 50),
      );
    await SaveRepository().clear();
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          playOpeningScene: false,
          playTutorial: false,
          ads: ads,
        ),
      ),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('banner_strip')), findsOneWidget);
    expect(find.byKey(const Key('fake_banner')), findsOneWidget);
    // The whole banner is on the screen, below the whole board.
    final banner = tester.getRect(find.byKey(const Key('fake_banner')));
    final screen = tester.getRect(find.byType(MaterialApp));
    expect(banner.bottom, lessThanOrEqualTo(screen.bottom));
    expect(banner.top, greaterThanOrEqualTo(tester.getRect(board).bottom));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });

  testWidgets('no banner during the tutorial', (tester) async {
    final ads = FakeAdService()
      ..fakeBanner = const SizedBox(key: Key('fake_banner'), height: 50);
    await SaveRepository().clear();
    await tester.pumpWidget(
      MaterialApp(home: BoardScreen(playOpeningScene: false, ads: ads)),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('banner_strip')), findsNothing);
    expect(find.byKey(const Key('fake_banner')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });
}
