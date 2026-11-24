import 'package:flutter/material.dart';

import '../../base_designs/sitewide/design_main.dart';
import '../../services/session_service.dart';
import 'club_creation.dart';
import 'event_creation_ui.dart';

/// The "+" button. Tapping it asks whether to create an event or a club,
/// then opens that form as the logged-in user.
///
/// Add it to any page with:
///   floatingActionButton: const CreateButton(),
class CreateButton extends StatelessWidget {
  const CreateButton({super.key});

  void _showMenu(BuildContext context) {
    final String? uid = SessionService.instance.currentUid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log in to create events and clubs.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.event, color: AppColors.purple),
              title: const Text('Create Event'),
              subtitle: const Text('A casual event, or one for a club you run'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                CreateEventPage.open(context, uid);
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups, color: AppColors.purple),
              title: const Text('Create Club'),
              subtitle: const Text('You\'ll be its owner'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                CreateClubPage.open(context, uid);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      tooltip: 'Create',
      backgroundColor: AppColors.purple,
      foregroundColor: AppColors.white,
      onPressed: () => _showMenu(context),
      child: const Icon(Icons.add),
    );
  }
}

/// Full screen page that holds the event creation form
class CreateEventPage extends StatelessWidget {
  const CreateEventPage({super.key, required this.currentUserId});

  final String currentUserId;

  static Future<void> open(BuildContext context, String currentUserId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CreateEventPage(currentUserId: currentUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.purple,
        backgroundColor: Colors.grey,
        title: const Text('Create Event'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: EventCreationForm(currentUserId: currentUserId),
        ),
      ),
    );
  }
}

/// Full screen page that holds the club creation form
class CreateClubPage extends StatelessWidget {
  const CreateClubPage({super.key, required this.currentUserId});

  final String currentUserId;

  static Future<void> open(BuildContext context, String currentUserId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CreateClubPage(currentUserId: currentUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.purple,
        backgroundColor: Colors.grey,
        title: const Text('Create Club'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ClubCreateForm(currentUserId: currentUserId),
        ),
      ),
    );
  }
}
