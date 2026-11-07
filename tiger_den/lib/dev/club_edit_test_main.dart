import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../firebase_options.dart';
import '../models/organization.dart';
import '../pages/widgets/club_Editing.dart';
import '../pages/widgets/club_creation.dart';
import '../services/firestore_service.dart';

/// A test-only way to open the club creation and editing pages as any
/// test user.
///
/// Run it with (from the tiger_den folder):
///   flutter run -t lib/dev/club_edit_test_main.dart -d emulator-5554
///
/// Pick who you are (test users from seed_data.dart), then tap
/// "Create a club" or tap a club to edit it.
///   User A - owner of User A's Club        -> can edit it
///   User B - owner of User B's Club, admin in User A's Club -> can edit both
///   User C - regular member                -> can't edit either
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
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ClubEditTestPage(),
  ));
}

class ClubEditTestPage extends StatefulWidget {
  const ClubEditTestPage({super.key});

  @override
  State<ClubEditTestPage> createState() => _ClubEditTestPageState();
}

class _ClubEditTestPageState extends State<ClubEditTestPage> {
  static const _testUsers = {
    'test_user_a': 'User A (owner of User A\'s Club)',
    'test_user_b': 'User B (owner of B\'s Club, admin in A\'s)',
    'test_user_c': 'User C (regular member)',
  };

  String _userId = 'test_user_a';

  // Created once (not in build) so the club list doesn't re-read the
  // database every time the page redraws.
  late final Stream<List<Organization>> _clubs =
      FirestoreService().streamPublicOrganizations();

  void _openEditor(Organization club) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('Edit: ${club.name}')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClubEditForm(orgId: club.id, currentUserId: _userId),
          ),
        ),
      ),
    ));
  }

  void _openCreator() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Create a Club')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClubCreateForm(currentUserId: _userId),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Club Edit Test (dev only)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _userId,
            decoration: const InputDecoration(labelText: 'Test as'),
            items: [
              for (final entry in _testUsers.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _userId = value!),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openCreator,
            icon: const Icon(Icons.add),
            label: const Text('Create a club'),
          ),
          const SizedBox(height: 24),
          Text('Tap a club to edit it',
              style: Theme.of(context).textTheme.titleMedium),
          StreamBuilder<List<Organization>>(
            stream: _clubs,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Could not load clubs: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final clubs = snapshot.data!;
              if (clubs.isEmpty) return const Text('No clubs found.');
              return Column(
                children: [
                  for (final club in clubs)
                    ListTile(
                      title: Text(club.name),
                      subtitle: Text(club.description,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _openEditor(club),
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
