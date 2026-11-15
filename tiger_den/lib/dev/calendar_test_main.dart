import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../base_designs/sitewide/design_main.dart';
import '../firebase_options.dart';
import '../pages/widgets/calendar.dart';

/// A test-only way to view the calendar as any test user.
///
/// Run it with (from the tiger_den folder):
///   flutter run -t lib/dev/calendar_test_main.dart -d emulator-5554
///
/// The test users' events (from seed_data.dart) are in early OCTOBER 2026,
/// so tap the < arrow to go back to October.
///   User A - "User A's Event"
///   User C - several events + a personal reminder ("+1 more" shows up)
///   User D - nothing (empty calendar)
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
      home: const CalendarTestPage(),
    ),
  );
}

class CalendarTestPage extends StatefulWidget {
  const CalendarTestPage({super.key});

  @override
  State<CalendarTestPage> createState() => _CalendarTestPageState();
}

class _CalendarTestPageState extends State<CalendarTestPage> {
  static const Map<String, String> _testUsers = <String, String>{
    'test_user_a': 'User A',
    'test_user_b': 'User B',
    'test_user_c': 'User C',
    'test_user_d': 'User D',
    'test_user_e': 'User E',
  };

  String _userId = 'test_user_a';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Test (dev only)'),
        actions: <Widget>[
          DropdownButton<String>(
            value: _userId,
            dropdownColor: AppColors.white,
            underline: const SizedBox.shrink(),
            iconEnabledColor: AppColors.white,
            // White text on the purple app bar; the menu itself stays dark text.
            selectedItemBuilder: (BuildContext context) => <Widget>[
              for (final String name in _testUsers.values)
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(color: AppColors.white),
                  ),
                ),
            ],
            items: <DropdownMenuItem<String>>[
              for (final MapEntry<String, String> entry in _testUsers.entries)
                DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
            ],
            onChanged: (String? value) {
              if (value != null) setState(() => _userId = value);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // A new key per user so the calendar reloads for each one.
      body: Calendar(
        key: ValueKey<String>(_userId),
        currentUserId: _userId,
      ),
    );
  }
}
