import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../services/session_service.dart';
import 'test_accounts.dart';

/// A separate, test-only way to launch the app that shows the current
/// login session. Use it until the real login screen exists.
///
/// Run it with (from the tiger_den folder):
///   flutter run -t lib/dev/session_test_main.dart -d emulator-5554
///
/// The normal app (lib/main.dart) is not affected.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SessionTestPage(),
  ));
}

class SessionTestPage extends StatefulWidget {
  const SessionTestPage({super.key});

  @override
  State<SessionTestPage> createState() => _SessionTestPageState();
}

class _SessionTestPageState extends State<SessionTestPage> {
  final _session = SessionService.instance;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Login failed: ${e.code}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Test (dev only)')),
      body: ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          if (!_session.isReady) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = _session.session;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                s == null ? 'Logged out' : 'Logged in',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (s != null) ...[
                SelectableText('User ID: ${s.uid}'),
                Text('Email: ${s.email ?? '-'}'),
                Text('Session ID: ${s.sessionId}'),
                Text('Session started: ${s.startedAt}'),
              ],
              const Divider(height: 32),
              for (final account in testAccounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() =>
                            _session.logIn(account.email, account.password)),
                    child: Text('Log in as ${account.label}'),
                  ),
                ),
              OutlinedButton(
                onPressed: _busy || s == null ? null : () => _run(_session.logOut),
                child: const Text('Log out'),
              ),
            ],
          );
        },
      ),
    );
  }
}
