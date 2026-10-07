import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/features/settings/account_screen.dart';
import 'package:whispers_of_joppa/features/settings/save_choice_dialog.dart';

import '../support/comfort_fakes.dart';
import '../support/fakes.dart';

void main() {
  late FakeAuthService auth;
  late int syncs;

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          auth: auth,
          syncNow: () async {
            syncs++;
            return 'Your game has been saved to your account.';
          },
        ),
      ),
    );
  }

  String message(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('account_message'))).data ?? '';

  Future<void> fill(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byKey(const Key('account_email')), email);
    await tester.enterText(find.byKey(const Key('account_password')), password);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  setUp(() {
    auth = FakeAuthService();
    syncs = 0;
  });

  testWidgets('signed out: fits a small phone and offers every way in', (
    tester,
  ) async {
    await show(tester);
    expect(tester.takeException(), isNull);
    for (final key in [
      'account_email',
      'account_password',
      'account_sign_in',
      'account_sign_up',
      'account_google',
      'account_apple',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('fits a small phone at the largest text size', (tester) async {
    useLargestText(tester);
    await show(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Apple is hidden where it is not available', (tester) async {
    auth.appleSignInAvailable = false;
    await show(tester);
    expect(find.byKey(const Key('account_apple')), findsNothing);
  });

  testWidgets('creating an account signs in and syncs', (tester) async {
    await show(tester);
    await fill(tester, 'naomi@example.com', 'secret123');
    await tapKey(tester, 'account_sign_up');
    expect(auth.user.value?.email, 'naomi@example.com');
    expect(syncs, 1);
    expect(
      tester.widget<Text>(find.byKey(const Key('account_signed_in_as'))).data,
      'Signed in as naomi@example.com',
    );
    expect(message(tester), 'Your game has been saved to your account.');
  });

  testWidgets(
    'when email must be confirmed, the player is told and not signed in',
    (tester) async {
      auth.requireConfirmation = true;
      await show(tester);
      await fill(tester, 'naomi@example.com', 'secret123');
      await tapKey(tester, 'account_sign_up');
      expect(auth.user.value, isNull);
      expect(syncs, 0);
      expect(message(tester), 'Check your email');
    },
  );

  testWidgets('a wrong password shows the reason and does not sign in', (
    tester,
  ) async {
    auth.accounts['naomi@example.com'] = 'right';
    await show(tester);
    await fill(tester, 'naomi@example.com', 'wrong');
    await tapKey(tester, 'account_sign_in');
    expect(auth.user.value, isNull);
    expect(message(tester), 'Invalid login credentials');
    expect(syncs, 0);
  });

  testWidgets('Google and Apple sign in and sync', (tester) async {
    await show(tester);
    await tapKey(tester, 'account_google');
    expect(auth.user.value?.id, 'google-user');
    expect(syncs, 1);
    await tapKey(tester, 'account_sign_out');
    expect(auth.user.value, isNull);
    await tapKey(tester, 'account_apple');
    expect(auth.user.value?.id, 'apple-user');
    expect(syncs, 2);
  });

  testWidgets('signed in: sync now, sign out', (tester) async {
    auth.signInAs('u1', 'naomi@example.com');
    await show(tester);
    await tapKey(tester, 'account_sync');
    expect(syncs, 1);
    await tapKey(tester, 'account_sign_out');
    expect(auth.user.value, isNull);
    expect(message(tester), contains('stays on this phone'));
    expect(find.byKey(const Key('account_sign_in')), findsOneWidget);
  });

  testWidgets('deleting the account asks first, and can be cancelled', (
    tester,
  ) async {
    auth.signInAs('u1', 'naomi@example.com');
    await show(tester);
    await tapKey(tester, 'account_delete');
    expect(find.byKey(const Key('account_delete_dialog')), findsOneWidget);
    await tester.tap(find.text('Keep my account'));
    await tester.pumpAndSettle();
    expect(auth.deleted, isFalse);
    expect(auth.user.value, isNotNull);

    await tapKey(tester, 'account_delete');
    await tester.tap(find.byKey(const Key('account_delete_confirm')));
    await tester.pumpAndSettle();
    expect(auth.deleted, isTrue);
    expect(auth.user.value, isNull);
    expect(message(tester), 'Your account has been deleted.');
  });

  testWidgets('the save choice shows both games and returns the choice', (
    tester,
  ) async {
    bool? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await showSaveChoice(
              context,
              localTasks: 1,
              localOrders: 2,
              cloudTasks: 5,
              cloudOrders: 6,
              cloudIsFurtherOn: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final text =
        tester.widget<Text>(find.byKey(const Key('save_choice_text'))).data ??
        '';
    expect(
      text,
      contains('This phone: 1 story tasks done, 2 orders delivered'),
    );
    expect(
      text,
      contains('Your account: 5 story tasks done, 6 orders delivered'),
    );
    expect(text, contains("Your account's game is further on"));
    await tester.tap(find.byKey(const Key('save_choice_cloud')));
    await tester.pumpAndSettle();
    expect(chosen, isTrue);
  });
}
