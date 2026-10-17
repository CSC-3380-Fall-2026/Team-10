import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'base_designs/sitewide/design_main.dart';
import 'firebase_options.dart';
import '/pages/widgets/event_creation_ui.dart';
import 'pages/widgets/login_page.dart';
import 'services/image_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await dotenv.load(fileName: ".env");

  // runApp(const MainApp());
  // runImageTest(); 
  runEventCreationForm();
}

//run app for login and signup page
void runLoginPage() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      home: const LoginPage(),
    ),
  );
}

///run app for eventcreation form.
void runEventCreationForm(){
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: EventCreationForm(currentUserId:"test_user_a"),
        ),
      ),
    ),
  );
}

void runImageTest() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: ImageTestForm(),
        ),
      ),
    ),
  );
}
  
