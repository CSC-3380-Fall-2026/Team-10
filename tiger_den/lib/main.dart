import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import '/base_designs/sitewide/design_main.dart';
import '/pages/widgets/event_creation_ui.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
  );

  
  runApp(const MainApp());





  //run app for eventcreation form. Maybe QA tester might want to add to a function for testing
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
