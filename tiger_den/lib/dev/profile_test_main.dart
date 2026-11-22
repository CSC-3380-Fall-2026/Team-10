import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../base_designs/sitewide/design_main.dart';
import '../firebase_options.dart';
import '../pages/widgets/profile_page.dart';

/// A test-only way to view the profile page as any test user, or as
/// whoever is logged in.
///
/// Run it with (from the tiger_den folder):
///   flutter run -t lib/dev/profile_test_main.dart -d emulator-5554
///
/// Test users (from seed_data.dart):
///   User A - owner of User A's Club, created events  -> tap club = edit
///   User B - owner of B's Club, admin of A's Club     -> tap club = edit
///   User C - regular member                           -> tap club = leave
///   User D - pending in User B's Club                 -> tap club = cancel
///   User E - no clubs, created an event               -> empty clubs list
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
      home: const ProfileTestPage(),
    ),
  );
}

class ProfileTestPage extends StatefulWidget {
  const ProfileTestPage({super.key});

  @override
  State<ProfileTestPage> createState() => _ProfileTestPageState();
}

class _ProfileTestPageState extends State<ProfileTestPage> {
  /// '' = whoever is logged in (SessionService)
  static const Map<String, String> _choices = <String, String>{
    'test_user_a': 'User A (owner)',
    'test_user_b': 'User B (owner + admin)',
    'test_user_c': 'User C (member)',
    'test_user_d': 'User D (pending)',
    'test_user_e': 'User E (no clubs)',
    '': 'Logged-in user',
  };

  String _choice = 'test_user_a';

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProfilePage(
          currentUserId: _choice.isEmpty ? null : _choice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Test (dev only)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _choice,
            decoration: const InputDecoration(labelText: 'View profile of'),
            items: <DropdownMenuItem<String>>[
              for (final MapEntry<String, String> entry in _choices.entries)
                DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
            ],
            onChanged: (String? value) {
              if (value != null) setState(() => _choice = value);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _openProfile,
            child: const Text('Open profile'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tip: "Leave club" and "Cancel join request" really change the '
            'database. To test without changing anything, tap "No" on the '
            '"Are you sure?" prompt.',
          ),
        ],
      ),
    );
  }
}
