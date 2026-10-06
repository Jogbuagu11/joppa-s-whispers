// AuthService backed by Supabase, with Google and Apple native sign-in.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logging/logging.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:whispers_of_joppa/app/config.dart';
import 'package:whispers_of_joppa/services/auth_service.dart';

final _log = Logger('Auth');

class SupabaseAuthService implements AuthService {
  final SupabaseClient _client;
  final ValueNotifier<AuthUser?> _user;
  late final StreamSubscription<AuthState> _subscription;
  bool _googleReady = false;

  SupabaseAuthService(this._client)
    : _user = ValueNotifier<AuthUser?>(_toUser(_client.auth.currentUser)) {
    _subscription = _client.auth.onAuthStateChange.listen(
      (state) => _user.value = _toUser(state.session?.user),
      onError: (Object e) => _log.warning('Auth state error: $e'),
    );
  }

  static AuthUser? _toUser(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);

  @override
  ValueListenable<AuthUser?> get user => _user;

  @override
  bool get appleSignInAvailable => !kIsWeb && Platform.isIOS;

  @override
  Future<AuthOutcome> signInWithEmail(String email, String password) =>
      _attempt('Email sign-in', () async {
        await _client.auth.signInWithPassword(email: email, password: password);
        return const AuthOutcome.success();
      });

  @override
  Future<AuthOutcome> signUpWithEmail(String email, String password) =>
      _attempt('Email sign-up', () async {
        final response = await _client.auth.signUp(
          email: email,
          password: password,
        );
        return response.session == null
            ? const AuthOutcome.success(
                'Check your email for a link to confirm your account, '
                'then sign in here.',
              )
            : const AuthOutcome.success();
      });

  @override
  Future<AuthOutcome> signInWithGoogle() =>
      _attempt('Google sign-in', () async {
        final google = GoogleSignIn.instance;
        if (!_googleReady) {
          await google.initialize(
            clientId: Platform.isIOS ? AppConfig.googleIosClientId : null,
            serverClientId: AppConfig.googleWebClientId,
          );
          _googleReady = true;
        }
        final account = await google.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          return const AuthOutcome.failure(
            'Google did not confirm who you are. Please try again.',
          );
        }
        await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        );
        return const AuthOutcome.success();
      });

  @override
  Future<AuthOutcome> signInWithApple() => _attempt('Apple sign-in', () async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      return const AuthOutcome.failure(
        'Apple did not confirm who you are. Please try again.',
      );
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );
    return const AuthOutcome.success();
  });

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      // The local session is cleared even if the server could not be told.
      _log.warning('Sign-out reported: ${e.message}');
    }
  }

  @override
  Future<AuthOutcome> deleteAccount() => _attempt('Delete account', () async {
    try {
      await _client.functions.invoke('delete-account');
    } on FunctionException catch (e) {
      _log.warning('delete-account returned ${e.status}: ${e.details}');
      return const AuthOutcome.failure(
        'Your account could not be deleted just now. Please try again.',
      );
    }
    await signOut();
    return const AuthOutcome.success();
  });

  /// Runs a sign-in step and turns any failure into a readable outcome.
  Future<AuthOutcome> _attempt(
    String what,
    Future<AuthOutcome> Function() action,
  ) async {
    try {
      return await action();
    } on AuthException catch (e) {
      _log.info('$what failed: ${e.message}');
      return AuthOutcome.failure(e.message);
    } on GoogleSignInException catch (e) {
      _log.info('$what failed: ${e.code} ${e.description}');
      return e.code == GoogleSignInExceptionCode.canceled
          ? const AuthOutcome.failure('Sign-in was cancelled.')
          : const AuthOutcome.failure(
              'Google sign-in did not work. Please try again.',
            );
    } on SignInWithAppleAuthorizationException catch (e) {
      _log.info('$what failed: ${e.code} ${e.message}');
      return e.code == AuthorizationErrorCode.canceled
          ? const AuthOutcome.failure('Sign-in was cancelled.')
          : const AuthOutcome.failure(
              'Apple sign-in did not work. Please try again.',
            );
    } on Exception catch (e, stack) {
      _log.warning('$what failed', e, stack);
      return const AuthOutcome.failure(
        'Something went wrong. Check your connection and try again.',
      );
    }
  }

  void dispose() {
    _subscription.cancel();
    _user.dispose();
  }
}
