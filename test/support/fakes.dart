// In-memory stand-ins for sign-in and cloud storage, used by tests.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/data/cloud_save_store.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/services/auth_service.dart';

class FakeAuthService implements AuthService {
  final ValueNotifier<AuthUser?> _user = ValueNotifier<AuthUser?>(null);

  /// email -> password for accounts that exist.
  final Map<String, String> accounts = {};

  /// When true, new accounts must confirm by email before signing in.
  bool requireConfirmation = false;
  bool deleted = false;

  @override
  bool appleSignInAvailable = true;

  @override
  ValueListenable<AuthUser?> get user => _user;

  void signInAs(String id, [String? email]) =>
      _user.value = AuthUser(id: id, email: email);

  @override
  Future<AuthOutcome> signInWithEmail(String email, String password) async {
    if (accounts[email] != password) {
      return const AuthOutcome.failure('Invalid login credentials');
    }
    signInAs('user-$email', email);
    return const AuthOutcome.success();
  }

  @override
  Future<AuthOutcome> signUpWithEmail(String email, String password) async {
    if (accounts.containsKey(email)) {
      return const AuthOutcome.failure('User already registered');
    }
    accounts[email] = password;
    if (requireConfirmation) {
      return const AuthOutcome.success('Check your email');
    }
    signInAs('user-$email', email);
    return const AuthOutcome.success();
  }

  @override
  Future<AuthOutcome> signInWithGoogle() async {
    signInAs('google-user', 'player@gmail.com');
    return const AuthOutcome.success();
  }

  @override
  Future<AuthOutcome> signInWithApple() async {
    signInAs('apple-user', 'player@icloud.com');
    return const AuthOutcome.success();
  }

  @override
  Future<void> signOut() async => _user.value = null;

  @override
  Future<AuthOutcome> deleteAccount() async {
    final email = _user.value?.email;
    if (email != null) accounts.remove(email);
    deleted = true;
    _user.value = null;
    return const AuthOutcome.success();
  }
}

class FakeCloudSaveStore implements CloudSaveStore {
  /// user id -> their cloud save.
  final Map<String, CloudSave> saves = {};

  /// When true, every call fails as if there were no connection.
  bool offline = false;
  int uploads = 0;
  DateTime _clock = DateTime.utc(2040, 1, 1);

  /// Puts a save in the cloud as if another phone had uploaded it.
  void seed(String userId, SaveState state) {
    _clock = _clock.add(const Duration(minutes: 1));
    saves[userId] = CloudSave(state: state, updatedAt: _clock);
  }

  @override
  Future<CloudSave?> fetch(String userId) async {
    if (offline) throw Exception('offline');
    return saves[userId];
  }

  @override
  Future<DateTime> upload(String userId, SaveState state) async {
    if (offline) throw Exception('offline');
    uploads++;
    _clock = _clock.add(const Duration(minutes: 1));
    saves[userId] = CloudSave(state: state, updatedAt: _clock);
    return _clock;
  }
}

/// A save with the given progress, for tests.
SaveState testSave({
  List<String> tasks = const [],
  List<String> orders = const [],
  int talents = 0,
  int blessings = 0,
}) => SaveState(
  items: const [],
  generators: const [],
  manna: 100,
  mannaLastRegen: DateTime.utc(2040),
  talents: talents,
  blessings: blessings,
  activeOrders: const [],
  pendingOrders: const [],
  completedOrders: orders,
  completedTasks: tasks,
  tutorialStep: tutorialFinished,
  lastOrderSkip: null,
);
