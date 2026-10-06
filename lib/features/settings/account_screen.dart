// Sign in, sync, sign out and delete the account.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/services/auth_service.dart';

final _log = Logger('AccountScreen');

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E6C8);
const _ink = Color(0xFF1A1205);

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.auth,
    required this.syncNow,
    this.onDeleted,
    this.onTestCrash,
  });

  /// Debug builds only: crashes the app on purpose, to check that crash
  /// reports arrive.
  final VoidCallback? onTestCrash;

  /// Called after the account has been deleted, to clear what this phone
  /// remembers about it.
  final Future<void> Function()? onDeleted;

  final AuthService auth;

  /// Syncs with the cloud and returns a short line saying what happened.
  final Future<String> Function() syncNow;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Runs a sign-in step, shows its message, and syncs if it signed in.
  Future<void> _run(Future<AuthOutcome> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      final outcome = await action();
      message = outcome.message;
      if (outcome.ok && widget.auth.user.value != null) {
        final synced = await widget.syncNow();
        if (synced.isNotEmpty) message = synced;
      }
    } on Exception catch (e, stack) {
      _log.warning('Account action failed', e, stack);
      message = 'Something went wrong. Please try again.';
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = message;
        });
      }
    }
  }

  Future<void> _sync() => _run(() async => const AuthOutcome.success());

  Future<void> _signOut() async {
    await widget.auth.signOut();
    if (!mounted) return;
    setState(() => _message = 'Signed out. Your game stays on this phone.');
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('account_delete_dialog'),
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account and your saved game from '
          'our servers. It cannot be undone. The game on this phone stays '
          'until you remove the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            key: const Key('account_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final outcome = await widget.auth.deleteAccount();
    if (outcome.ok) await widget.onDeleted?.call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = outcome.ok
          ? 'Your account has been deleted.'
          : outcome.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('account_screen'),
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: _gold,
        title: const Text('Account'),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<AuthUser?>(
          valueListenable: widget.auth.user,
          builder: (context, user, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...(user == null ? _signedOut() : _signedIn(user)),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: _gold),
                    ),
                  ),
                if (_message case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      message,
                      key: const Key('account_message'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _cream, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _signedOut() => [
    const Text(
      'Sign in to keep your game safe and play it on another phone. '
      'You can keep playing without an account.',
      style: TextStyle(color: _cream, fontSize: 14, height: 1.3),
    ),
    const SizedBox(height: 16),
    _field(_email, 'Email', const Key('account_email')),
    const SizedBox(height: 10),
    _field(_password, 'Password', const Key('account_password'), hide: true),
    const SizedBox(height: 14),
    _button(
      'Sign in',
      const Key('account_sign_in'),
      () => _run(
        () => widget.auth.signInWithEmail(_email.text.trim(), _password.text),
      ),
    ),
    _button(
      'Create account',
      const Key('account_sign_up'),
      () => _run(
        () => widget.auth.signUpWithEmail(_email.text.trim(), _password.text),
      ),
      outlined: true,
    ),
    const SizedBox(height: 18),
    _button(
      'Continue with Google',
      const Key('account_google'),
      () => _run(widget.auth.signInWithGoogle),
      outlined: true,
    ),
    if (widget.auth.appleSignInAvailable)
      _button(
        'Continue with Apple',
        const Key('account_apple'),
        () => _run(widget.auth.signInWithApple),
        outlined: true,
      ),
  ];

  List<Widget> _signedIn(AuthUser user) => [
    Text(
      'Signed in as ${user.email ?? 'your account'}',
      key: const Key('account_signed_in_as'),
      style: const TextStyle(color: _cream, fontSize: 16),
    ),
    const SizedBox(height: 6),
    const Text(
      'Your game is saved to your account as you play.',
      style: TextStyle(color: Color(0xFFBFA77A), fontSize: 13),
    ),
    const SizedBox(height: 18),
    _button('Sync now', const Key('account_sync'), _sync),
    _button(
      'Sign out',
      const Key('account_sign_out'),
      _signOut,
      outlined: true,
    ),
    const SizedBox(height: 28),
    TextButton(
      key: const Key('account_delete'),
      onPressed: _busy ? null : _confirmDelete,
      child: const Text('Delete account', style: TextStyle(color: Colors.red)),
    ),
    if (kDebugMode && widget.onTestCrash != null)
      TextButton(
        key: const Key('account_test_crash'),
        onPressed: widget.onTestCrash,
        child: const Text('Test crash (debug only)'),
      ),
  ];

  Widget _field(
    TextEditingController controller,
    String label,
    Key key, {
    bool hide = false,
  }) => TextField(
    key: key,
    controller: controller,
    obscureText: hide,
    autocorrect: false,
    keyboardType: hide
        ? TextInputType.visiblePassword
        : TextInputType.emailAddress,
    style: const TextStyle(color: _cream),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFBFA77A)),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF5C3D0D)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _gold),
      ),
    ),
  );

  Widget _button(
    String label,
    Key key,
    VoidCallback onPressed, {
    bool outlined = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: outlined
        ? OutlinedButton(
            key: key,
            onPressed: _busy ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: const BorderSide(color: _gold),
              minimumSize: const Size.fromHeight(46),
            ),
            child: Text(label),
          )
        : FilledButton(
            key: key,
            onPressed: _busy ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              minimumSize: const Size.fromHeight(46),
            ),
            child: Text(label, style: const TextStyle(color: Colors.black)),
          ),
  );
}
