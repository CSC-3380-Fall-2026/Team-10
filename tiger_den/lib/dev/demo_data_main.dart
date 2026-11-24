import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../base_designs/sitewide/design_main.dart';
import '../firebase_options.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'demo_data.dart';
import 'test_accounts.dart';

/// A test-only page that sets up the demo account's clubs and events.
///
/// Run it with (from the tiger_den folder):
///   flutter run -t lib/dev/demo_data_main.dart -d emulator-5554
///
/// "Create / refresh demo data" logs in as testuser1 and builds everything
/// in demo_data.dart. Safe to tap again: it reuses what's already there and
/// moves the events back into this week.
///
/// "Reset live demo steps" leaves Tiger Chess Club and removes the RSVP to
/// Friday Night Blitz, so the demo can be practiced again.
///
/// The normal app (lib/main.dart) is not affected.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await dotenv.load(fileName: '.env'); // needed for search (Algolia) keys
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      home: const DemoDataPage(),
    ),
  );
}

class DemoDataPage extends StatefulWidget {
  const DemoDataPage({super.key});

  @override
  State<DemoDataPage> createState() => _DemoDataPageState();
}

class _DemoDataPageState extends State<DemoDataPage> {
  final TestAccount _account = testAccounts.first;
  final List<String> _log = <String>[];
  bool _busy = false;

  void _addLog(String line) {
    if (!mounted) return;
    setState(() => _log.add(line));
  }

  /// Logs in as the demo account and returns its profile
  Future<AppUser?> _logInAsDemoAccount() async {
    await AuthService().logIn(_account.email, _account.password);
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _addLog('Could not log in as ${_account.email}.');
      return null;
    }
    final AppUser? me = await FirestoreService().getUser(uid);
    if (me == null) {
      _addLog('${_account.email} has no profile yet. Use "Create test '
          'profile" on the session test page first.');
      return null;
    }
    _addLog('Logged in as ${me.displayName} (${_account.email})');
    return me;
  }

  Future<void> _run(Future<void> Function(AppUser me) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _log.clear();
    });
    try {
      final AppUser? me = await _logInAsDemoAccount();
      if (me != null) {
        await action(me);
        _addLog('Done!');
      }
    } catch (e) {
      _addLog('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Data (dev only)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Demo account: ${_account.email}'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run((AppUser me) =>
                    DemoData().createOrRefresh(me, _addLog)),
            child: const Text('Create / refresh demo data'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run((AppUser me) =>
                    DemoData().resetLiveSteps(me.id, _addLog)),
            child: const Text('Reset live demo steps'),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          for (final String line in _log)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(line),
            ),
        ],
      ),
    );
  }
}
