import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'base_designs/sitewide/design_main.dart';
import 'firebase_options.dart';
import 'pages/widgets/event_creation_ui.dart';
import 'pages/widgets/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Run the Login screen:
  runApp(const LoginApp());

  // Or run the Event Creation form:
  // runApp(
  //   const MaterialApp(
  //     debugShowCheckedModeBanner: false,
  //     home: Scaffold(
  //       body: SafeArea(
  //         child: EventCreationForm(),
  //       ),
  //     ),
  //   ),
  // );
}

/// Commentable-out App class to run the app and show the login screen
/// styled with the universal design from [design_main.dart].
class LoginApp extends StatelessWidget {
  const LoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      home: const LoginPage(),
    );
  }
}

