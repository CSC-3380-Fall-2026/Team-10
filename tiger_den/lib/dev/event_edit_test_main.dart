import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../firebase_options.dart';
import '../models/event.dart';
import '../pages/widgets/event_editing.dart';

/// A test-only way to open the event editing page as any test user.
///
/// Run it with (from the tiger_den folder):
///   flutter run -t lib/dev/event_edit_test_main.dart -d emulator-5554
///
/// Pick who you are (test users from seed_data.dart), then tap an event.
///   User A - created "User A's Event"                 -> can edit it
///   User B - a host of "User A's Event"               -> can edit it
///   User C - only an attendee                         -> can't edit it
///   User E - created "User E's Event (No Club, Virtual)" -> can edit that one
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
    home: EventEditTestPage(),
  ));
}

class EventEditTestPage extends StatefulWidget {
  const EventEditTestPage({super.key});

  @override
  State<EventEditTestPage> createState() => _EventEditTestPageState();
}

class _EventEditTestPageState extends State<EventEditTestPage> {
  static const _testUsers = {
    'test_user_a': 'User A (created User A\'s Event)',
    'test_user_b': 'User B (host of User A\'s Event)',
    'test_user_c': 'User C (attendee only)',
    'test_user_e': 'User E (created User E\'s Event)',
  };

  String _userId = 'test_user_a';

  // All events (newest first, max 30), including past and members-only ones,
  // since the test events from seed_data.dart are dated in early October.
  // Created once (not in build) so the list doesn't re-read the database
  // every time the page redraws.
  late final Stream<List<Event>> _events = FirebaseFirestore.instance
      .collection('events')
      .orderBy('startTime', descending: true)
      .limit(30)
      .snapshots()
      .map((snap) => snap.docs.map(Event.fromDoc).toList());

  void _openEditor(Event event) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('Edit: ${event.title}')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: EventEditForm(eventId: event.id, currentUserId: _userId),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Edit Test (dev only)')),
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
          const SizedBox(height: 24),
          Text('Tap an event to edit it',
              style: Theme.of(context).textTheme.titleMedium),
          StreamBuilder<List<Event>>(
            stream: _events,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Could not load events: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final events = snapshot.data!;
              if (events.isEmpty) return const Text('No events found.');
              return Column(
                children: [
                  for (final event in events)
                    ListTile(
                      title: Text(event.title),
                      subtitle: Text(
                        '${event.startTime}  ·  ${event.location.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _openEditor(event),
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
