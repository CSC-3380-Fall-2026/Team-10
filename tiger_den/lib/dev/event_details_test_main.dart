import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../base_designs/sitewide/design_main.dart';
import '../firebase_options.dart';
import '../models/event.dart';
import '../pages/widgets/event_details_page.dart';

/// A test-only way to open any event's details page as any test user.
///
/// Run it with (from the tiger_den folder):
///   flutter run -t lib/dev/event_details_test_main.dart -d emulator-5554
///
/// RSVPing here really changes the database (the event's "X going" count and
/// the test user's calendar). Tap "Cancel RSVP" afterward to undo it.
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
      home: const EventDetailsTestPage(),
    ),
  );
}

class EventDetailsTestPage extends StatefulWidget {
  const EventDetailsTestPage({super.key});

  @override
  State<EventDetailsTestPage> createState() => _EventDetailsTestPageState();
}

class _EventDetailsTestPageState extends State<EventDetailsTestPage> {
  /// '' = whoever is logged in (SessionService)
  static const Map<String, String> _choices = <String, String>{
    'test_user_a': 'User A',
    'test_user_b': 'User B',
    'test_user_c': 'User C',
    'test_user_d': 'User D',
    'test_user_e': 'User E',
    '': 'Logged-in user',
  };

  String _choice = 'test_user_d';

  // All events, latest date first (max 30). Created once (not in build)
  // so the list doesn't re-read the database every time the page redraws.
  late final Stream<List<Event>> _events = FirebaseFirestore.instance
      .collection('events')
      .orderBy('startTime', descending: true)
      .limit(30)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              Event.fromDoc(doc))
          .toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Details Test (dev only)')),
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
          Text('Tap an event (newest first)',
              style: Theme.of(context).textTheme.titleMedium),
          StreamBuilder<List<Event>>(
            stream: _events,
            builder:
                (BuildContext context, AsyncSnapshot<List<Event>> snapshot) {
              if (snapshot.hasError) {
                return Text('Could not load events: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final List<Event> events = snapshot.data!;
              if (events.isEmpty) return const Text('No events found.');
              return Column(
                children: <Widget>[
                  for (final Event event in events)
                    ListTile(
                      title: Text(event.title),
                      subtitle: Text(
                        '${event.startTime} · ${event.attendeeCount} going',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => EventDetailsPage.open(
                        context,
                        event.id,
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
