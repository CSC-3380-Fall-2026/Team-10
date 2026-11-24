import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../base_designs/sitewide/design_main.dart';
import '../firebase_options.dart';
import '../models/organization.dart';
import '../pages/widgets/club_page.dart';
import '../services/firestore_service.dart';

/// A test-only way to open any club's page as any test user.
///
/// Run it with (from the tiger_den folder):
///   flutter run -t lib/dev/club_page_test_main.dart -d emulator-5554
///
/// Test users (from seed_data.dart):
///   User A - owner of User A's Club              (sees "You own this club")
///   User B - owner of User B's Club, admin of User A's Club
///   User C - member of both clubs                    (sees "Leave club")
///   User D - pending in User B's Club                (sees "Cancel request")
///   User E - in no clubs                             (sees "Join")
///
/// Joining and leaving here really change the database (member count and
/// the test user's "My Clubs"). Leave or cancel afterward to undo it.
///
/// The normal app (lib/main.dart) is not affected.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      home: const ClubPageTestPage(),
    ),
  );
}

class ClubPageTestPage extends StatefulWidget {
  const ClubPageTestPage({super.key});

  @override
  State<ClubPageTestPage> createState() => _ClubPageTestPageState();
}

class _ClubPageTestPageState extends State<ClubPageTestPage> {
  /// '' = whoever is logged in (SessionService)
  static const Map<String, String> _choices = <String, String>{
    'test_user_a': 'User A (owner of A\'s Club)',
    'test_user_b': 'User B (owner of B\'s, admin of A\'s)',
    'test_user_c': 'User C (member of both)',
    'test_user_d': 'User D (pending in B\'s Club)',
    'test_user_e': 'User E (no clubs)',
    '': 'Logged-in user',
  };

  String _choice = 'test_user_e';

  // Created once (not in build) so the list doesn't re-read the database
  // every time the page redraws.
  late final Stream<List<Organization>> _clubs =
      FirestoreService().streamPublicOrganizations();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Club Page Test (dev only)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _choice,
            decoration: const InputDecoration(labelText: 'View as'),
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
          Text('Tap a club', style: Theme.of(context).textTheme.titleMedium),
          StreamBuilder<List<Organization>>(
            stream: _clubs,
            builder: (BuildContext context,
                AsyncSnapshot<List<Organization>> snapshot) {
              if (snapshot.hasError) {
                return Text('Could not load clubs: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final List<Organization> clubs = snapshot.data!;
              if (clubs.isEmpty) return const Text('No clubs found.');
              return Column(
                children: <Widget>[
                  for (final Organization club in clubs)
                    ListTile(
                      title: Text(club.name),
                      subtitle: Text(
                        '${club.memberCount} members · '
                        '${club.requiresApproval ? 'approval needed' : 'open'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => ClubPage.open(
                        context,
                        club.id,
                        currentUserId: _choice.isEmpty ? null : _choice,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
