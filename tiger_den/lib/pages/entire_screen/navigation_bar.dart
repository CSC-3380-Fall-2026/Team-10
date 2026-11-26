import 'package:flutter/material.dart';

import '../widgets/calendar.dart';
import '../widgets/home_page.dart';
import '../widgets/profile_page.dart';

/// Shared bottom navigation bar used across top-level screens
/// (Home, Calendar, Profile, and Settings).
class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.currentIndex,
  });

  /// The index of the currently active tab:
  /// 0 = Home, 1 = Calendar, 2 = Profile, 3 = Settings.
  final int currentIndex;

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    final Widget? destination = switch (index) {
      0 => const HomePage(),
      1 => const Calendar(),
      2 => const ProfilePage(),
      // TODO: Add Settings page navigation once implemented.
      _ => null,
    };

    if (destination == null) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => destination,
        transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 150),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.purple,
      unselectedItemColor: Colors.grey,
      onTap: (int index) => _onItemTapped(context, index),
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
        // BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}
