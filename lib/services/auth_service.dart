// Sign-in, sign-out and account deletion, behind an interface so screens and
// tests do not depend on Supabase.
import 'package:flutter/foundation.dart';

/// The signed-in player.
class AuthUser {
  final String id;
  final String? email;

  const AuthUser({required this.id, this.email});
}

/// The result of trying to sign in or sign up, in words a player can read.
class AuthOutcome {
  final bool ok;

  /// A message to show: why it failed, or what to do next.
  final String? message;

  const AuthOutcome.success([this.message]) : ok = true;
  const AuthOutcome.failure(String this.message) : ok = false;
}

abstract class AuthService {
  /// The signed-in player, or null. Listeners are told when it changes.
  ValueListenable<AuthUser?> get user;

  /// Whether "Sign in with Apple" can be offered on this device.
  bool get appleSignInAvailable;

  Future<AuthOutcome> signInWithEmail(String email, String password);

  /// Creates an account. If the project requires email confirmation, the
  /// outcome is ok with a message telling the player to check their email,
  /// and [user] stays null until they confirm and sign in.
  Future<AuthOutcome> signUpWithEmail(String email, String password);

  Future<AuthOutcome> signInWithGoogle();
  Future<AuthOutcome> signInWithApple();
  Future<void> signOut();

  /// Permanently deletes the account and everything stored for it online.
  Future<AuthOutcome> deleteAccount();
}
