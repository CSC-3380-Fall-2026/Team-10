import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../services/auth_service.dart';

/// A test-only page for the password reset flow:
///   1. send a reset email,
///   2. reset the password using the link in the email,
///   3. check that logging in with the NEW password works.
///
/// Run it with (from the tiger_den folder):
///   flutter run -t lib/dev/password_reset_test_main.dart -d emulator-5554
///
/// The normal app (lib/main.dart) is not affected.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PasswordResetTestPage(),
  ));
}

class PasswordResetTestPage extends StatefulWidget {
  const PasswordResetTestPage({super.key});

  @override
  State<PasswordResetTestPage> createState() => _PasswordResetTestPageState();
}

class _PasswordResetTestPageState extends State<PasswordResetTestPage> {
  final _auth = AuthService();
  final _resetEmail = TextEditingController();
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  bool _busy = false;
  String? _resetResult;
  bool _resetOk = false;
  String? _loginResult;
  bool _loginOk = false;

  @override
  void dispose() {
    _resetEmail.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    setState(() => _busy = true);
    final email = _resetEmail.text.trim();
    try {
      await _auth.sendPasswordReset(email);
      _resetOk = true;
      _resetResult = 'If an account exists for $email, a reset link was sent. '
          'Check the inbox (and the spam folder).';
    } on PasswordResetException catch (e) {
      _resetOk = false;
      _resetResult = '${e.message}  (code: ${e.code})';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tryLogin() async {
    setState(() => _busy = true);
    try {
      await _auth.logIn(_loginEmail.text, _loginPassword.text);
      _loginOk = true;
      _loginResult = 'Logged in successfully with this password.';
      await _auth.logOut(); // don't leave this test login active
    } on FirebaseAuthException catch (e) {
      _loginOk = false;
      _loginResult = 'Login failed (code: ${e.code})';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _result(String? text, bool ok) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: TextStyle(color: ok ? Colors.green.shade800 : Colors.red.shade700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Password Reset Test (dev only)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('1. Send a reset email', style: heading),
          const SizedBox(height: 8),
          TextField(
            controller: _resetEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _sendReset,
            child: const Text('Send reset email'),
          ),
          _result(_resetResult, _resetOk),
          const Divider(height: 40),
          Text('2. Open the link in the email and choose a new password',
              style: heading),
          const Divider(height: 40),
          Text('3. Check the new password works', style: heading),
          const SizedBox(height: 8),
          TextField(
            controller: _loginEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: _loginPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _tryLogin,
            child: const Text('Try logging in'),
          ),
          _result(_loginResult, _loginOk),
        ],
      ),
    );
  }
}
