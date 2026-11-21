import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tiger_den/pages/widgets/forgot_passoword_page.dart';
// import 'package:model2vec/model2vec.dart';
import 'base_designs/sitewide/design_main.dart';
import 'firebase_options.dart';
import '/pages/widgets/event_creation_ui.dart';
import 'pages/widgets/login_page.dart';
import 'services/image_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import '../test/search_service_test.dart';
import 'pages/widgets/home_page.dart';
import '/pages/widgets/forgot_passoword_page.dart';
import 'pages/widgets/calendar.dart';
import 'pages/entire_screen/search_page.dart';
import 'pages/widgets/filter_widget.dart';
import 'pages/widgets/profile_page.dart';
// import 'page'


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
  );
  
  try {
  await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Could not load .env file: $e");
  }
 

  // runForgotPassword();
  // runImageTest(); 
  // runEventCreationForm();
  runHomePage();
  // runProfilePage();
  // runCalendar();
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

void runForgotPassword() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      home: const ForgotPasswordPage(),
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

void runHomePage() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: true,
      builder: (context, child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      home: const HomePage(),
    ),
  );
}

//Launches directly to profile page, but page should also be accessible from runHomePage()
void runProfilePage() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: true,
      builder: (context, child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      home: const ProfilePage(),
    ),
  );
}
void runSearchPage() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: true,
      builder: (context, child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      home: SearchPage(),
    ),
  );
}
  
void runCalendar() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Calendar(),
    ),
  );
}

//Page switcher that should work to switch between the pages easier, use openPage("page_name") in main to open any page.
void openPage(String pageName) {
  Widget page;
  switch (pageName) {
    case 'login':
      page = const LoginPage();
      break;
    case 'forgot_password':
      page = const ForgotPasswordPage();
      break;
    case 'profile':
      page = const ProfilePage();
      break;
    case 'search':
      page = const SearchPage();
      break;
    case 'calendar':
      page = const Calendar();
      break;
    case 'create_event':
      page = const Scaffold(
        body: SafeArea(
          child: EventCreationForm(currentUserId: 'test_user_a'),
        ),
      );
      break;
    case 'home':
    default:
      page = const HomePage();
      break;
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      home: page,
    ),
  );
}