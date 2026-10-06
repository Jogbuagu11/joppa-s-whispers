// Milestone 14: sign in, save to the account, and get the game back on a
// "new phone". Uses stand-in sign-in and cloud services, so no real account
// or network is involved.
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/app/cloud_sync.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/data/sync_base_repository.dart';
import 'package:whispers_of_joppa/game/board/board_cloud.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final board = find.byType(GameWidget<BoardGame>);

  testWidgets('sign up, play, then recover the game on a new phone', (
    tester,
  ) async {
    final auth = FakeAuthService();
    final store = FakeCloudSaveStore();
    final cloud = BoardCloud(
      auth: auth,
      sync: CloudSync(auth: auth, store: store, bases: SyncBaseRepository()),
      uploadEvery: const Duration(seconds: 1),
    );
    Future<void> cleanPhone() async {
      await SaveRepository().clear();
      await SyncBaseRepository().clear();
    }

    await cleanPhone();
    addTearDown(cleanPhone);

    Future<void> open(Key key) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BoardScreen(
            key: key,
            playOpeningScene: false,
            playTutorial: false,
            cloud: cloud,
          ),
        ),
      );
      for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> settle() async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
    }

    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';

    // --- Create an account from the board. ---
    await open(const Key('first-phone'));
    await tester.tap(find.byKey(const Key('account_button')));
    await settle();
    expect(find.byKey(const Key('account_screen')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('account_email')),
      'naomi@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('account_password')),
      'secret123',
    );
    await tester.tap(find.byKey(const Key('account_sign_up')));
    await settle();
    expect(text('account_signed_in_as'), 'Signed in as naomi@example.com');
    expect(text('account_message'), contains('saved to your account'));
    final userId = auth.user.value?.id;
    expect(userId, isNotNull);
    expect(store.saves[userId], isNotNull, reason: 'the game was uploaded');
    final uploadsAfterSignUp = store.uploads;

    // --- Keep playing: progress reaches the account by itself. ---
    await tester.pageBack();
    await settle();
    final ready = find.byWidgetPredicate(
      (w) =>
          w is FilledButton &&
          w.onPressed != null &&
          w.key.toString().contains('order_deliver_'),
    );
    expect(ready, findsWidgets);
    await tester.tap(ready.first);
    await tester.pump(const Duration(milliseconds: 500));
    final talents = text('talents_count');
    final blessings = text('blessings_count');
    expect(talents, isNot('0'));
    // Past the 2-second local save delay and the upload interval.
    await tester.pump(const Duration(seconds: 5));
    expect(store.uploads, greaterThan(uploadsAfterSignUp));
    expect(store.saves[userId]?.state.completedOrders.length, 1);
    expect('${store.saves[userId]?.state.talents}', talents);

    // --- A "new phone": nothing saved locally, same account signed in. ---
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await cleanPhone();
    await open(const Key('new-phone'));
    // The launch check finds the account's game and brings it over.
    for (int i = 0; i < 100 && text('talents_count') != talents; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(text('talents_count'), talents);
    expect(text('blessings_count'), blessings);
    final game = tester.widget<GameWidget<BoardGame>>(board).game;
    expect(
      game?.snapshotItems().length,
      store.saves[userId]?.state.items.length,
    );

    // --- Delete the account from the app. ---
    await tester.tap(find.byKey(const Key('account_button')));
    await settle();
    await tester.ensureVisible(find.byKey(const Key('account_delete')));
    await tester.tap(find.byKey(const Key('account_delete')));
    await settle();
    await tester.tap(find.byKey(const Key('account_delete_confirm')));
    await settle();
    expect(auth.deleted, isTrue);
    expect(auth.user.value, isNull);
    expect(text('account_message'), 'Your account has been deleted.');
  });
}
