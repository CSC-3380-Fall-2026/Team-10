import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../services/current_user_service.dart';
import '../services/firestore_service.dart';
import '../services/session_service.dart';
import 'test_accounts.dart';

/// A separate, test-only way to launch the app that shows the current
/// login session and the logged-in user's profile. Use it until the real
/// login screen exists.
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
  final _me = CurrentUserService.instance;
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
    } on FirebaseException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Database error: ${e.code}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Creates the profile document for the logged-in test account,
  /// using the matching entry in test_accounts.dart.
  Future<void> _createTestProfile() async {
    final s = _session.session!;
    final account = testAccounts.firstWhere(
      (a) => a.email == s.email,
      orElse: () => TestAccount('Test User', s.email ?? '', '', 'test_user'),
    );
    await FirestoreService().createUserProfile(AppUser(
      id: s.uid,
      email: s.email ?? '',
      username: account.username,
      displayName: account.label,
      firstName: 'Test',
      lastName: 'User',
      bio: 'TEST LOGIN ACCOUNT: ${account.label}',
      major: 'Test Major',
      gradYear: 2028,
      interests: ['testing'],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Test (dev only)')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_session, _me]),
        builder: (context, _) {
          if (!_session.isReady) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = _session.session;
          final textTheme = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---- Session -------------------------------------------------
              Text(
                s == null ? 'Logged out' : 'Logged in',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (s != null) ...[
                SelectableText('User ID: ${s.uid}'),
                Text('Email: ${s.email ?? '-'}'),
                Text('Session ID: ${s.sessionId}'),
                Text('Session started: ${s.startedAt}'),
              ],

              // ---- Profile loaded into the session -------------------------
              if (s != null) ...[
                const Divider(height: 32),
                Text('Profile (users/${s.uid})', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_me.isLoading)
                  const Text('Loading profile...')
                else if (_me.user != null)
                  _ProfileDetails(user: _me.user!)
                else ...[
                  const Text('No profile found for this account.'),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => _run(_createTestProfile),
                    child: const Text('Create test profile'),
                  ),
                ],
              ],

              // ---- Buttons --------------------------------------------------
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
                onPressed:
                    _busy || s == null ? null : () => _run(_session.logOut),
                child: const Text('Log out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Display name: ${user.displayName}'),
        Text('Username: ${user.username}'),
        Text('Email: ${user.email}'),
        Text('Bio: ${user.bio}'),
        Text('Major: ${user.major ?? '-'}  (class of ${user.gradYear ?? '-'})'),
        Text('Interests: ${user.interests.join(', ')}'),
        Text('Profile created: ${user.createdAt ?? '-'}'),
      ],
    );
  }
}
