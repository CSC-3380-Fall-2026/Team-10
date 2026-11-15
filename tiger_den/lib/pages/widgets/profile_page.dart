import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../base_designs/sitewide/design_main.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../models/organization.dart';
import '../../services/auth_service.dart';
import '../../services/current_user_service.dart';
import '../../services/firestore_service.dart';
import 'calendar.dart';
import 'home_page.dart';

/// Profile Page for Tiger Den, based off wireframes
/// TODO: Ensure full firebase integration, find out a way to fix transition between pages
class ProfilePage extends StatefulWidget {
  final AppUser? initialUser;
  final List<String>? initialClubs;
  final List<String>? initialEvents;
  final AuthService? authService;
  final FirestoreService? firestoreService;
  final VoidCallback? onSignOut;

  const ProfilePage({
    super.key,
    this.initialUser,
    this.initialClubs,
    this.initialEvents,
    this.authService,
    this.firestoreService,
    this.onSignOut,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AuthService? _authServiceInstance;
  FirestoreService? _firestoreServiceInstance;

  AuthService? _getAuthService() {
    if (widget.authService != null) return widget.authService;
    try {
      return _authServiceInstance ??= AuthService();
    } catch (_) {
      return null;
    }
  }

  FirestoreService? _getFirestoreService() {
    if (widget.firestoreService != null) return widget.firestoreService;
    try {
      return _firestoreServiceInstance ??= FirestoreService();
    } catch (_) {
      return null;
    }
  }
  int _currentMenuIndex = 2; // Profile is the 3rd item (index 2)
  bool _signedOut = false;

  // Fallback data matching the wireframe mockups
  static const List<String> _fallbackClubs = [
    'Tiger Photography Guild',
    'LSU Chess & Strategy Group',
    'Rec Outdoor Adventure Club',
  ];

  static const List<String> _fallbackEvents = [
    'Mike Watch 2k26',
    'Homecoming Tailgate Bash',
    'Intramural Championship Match',
  ];

  AppUser? _getCurrentUser() {
    if (_signedOut) return null;
    if (widget.initialUser != null) return widget.initialUser;
    try {
      return CurrentUserService.instance.user;
    } catch (_) {
      return null;
    }
  }

  // Sign-out prompt

  Future<void> _handleSignOut() async {
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: const Text(
            'Are you sure you want to sign out?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple,
                side: const BorderSide(color: Colors.purple, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text(
                'No',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text(
                'Yes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      try {
        final auth = _getAuthService();
        if (auth != null) {
          await auth.logOut();
        }
      } catch (e) {
        debugPrint('Sign out notice: $e');
      }

      if (mounted) {
        setState(() {
          _signedOut = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully.'),
            backgroundColor: Colors.purple,
          ),
        );

        widget.onSignOut?.call();
      }
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == _currentMenuIndex) return;

    if (index == 0) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } else if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const Calendar()),
      );
    } else if (index == 2) {
      setState(() => _currentMenuIndex = 2);
    } else if (index == 3) {
      setState(() => _currentMenuIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _getCurrentUser();

    final String username = user?.username.isNotEmpty == true
        ? '@${user!.username}'
        : '@tiger_den';

    final String displayName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (user != null && ('${user.firstName} ${user.lastName}'.trim().isNotEmpty)
            ? '${user.firstName} ${user.lastName}'.trim()
            : 'Mike the Tiger');

    final String bio = user?.bio.isNotEmpty == true
        ? user!.bio
        : 'Sophmore in Computer Science. Interested in Software Engineering, Robotics, and more events around campus!';

    final String? photoUrl = user?.profilePhotoUrl;

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.purple,
        backgroundColor: Colors.grey,
        title: const Text('Tiger Den Profile'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header (Slide 5: Avatar on left, Username and Name on right)
            Row(
              children: [
                _buildAvatar(photoUrl, displayName),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 15.0,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20.0),

            // Bio Section (Slide 5: Bordered container for Bio)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bio',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    bio,
                    style: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24.0),

            // Clubs Section (Slides 5 & 6)
            const Text(
              'Clubs',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12.0),
            _buildClubsList(user),

            const SizedBox(height: 24.0),

            // Events Section (Slide 6)
            const Text(
              'Events',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12.0),
            _buildEventsList(user),

            const SizedBox(height: 32.0),

            // Sign Out Button (Slide 6)
            SizedBox(
              width: double.infinity,
              height: 48.0,
              child: ElevatedButton(
                onPressed: _handleSignOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16.0),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentMenuIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        onTap: _onBottomNavTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String displayName) {
    return Container(
      width: 68.0,
      height: 68.0,
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.purple.shade200, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.0),
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _avatarFallback(displayName),
              )
            : _avatarFallback(displayName),
      ),
    );
  }

  Widget _avatarFallback(String displayName) {
    return Center(
      child: displayName.isNotEmpty
          ? Text(
              displayName[0].toUpperCase(),
              style: TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.bold,
                color: AppColors.purple,
              ),
            )
          : const Icon(
              Icons.person,
              size: 36.0,
              color: Colors.purple,
            ),
    );
  }

  Widget _buildClubsList(AppUser? user) {
    if (widget.initialClubs != null) {
      return _buildClubCards(widget.initialClubs!);
    }

    final fs = _getFirestoreService();
    if (user != null && !_signedOut && fs != null) {
      return StreamBuilder<List<Membership>>(
        stream: fs.streamMyMemberships(user.id),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final names = snapshot.data!.map((m) => m.orgName).toList();
            return _buildClubCards(names);
          }
          return _buildClubCards(_fallbackClubs);
        },
      );
    }

    return _buildClubCards(_fallbackClubs);
  }

  Widget _buildClubCards(List<String> clubs) {
    if (clubs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No clubs joined yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: clubs.map((club) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10.0),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34.0,
                height: 34.0,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.purple,
                  size: 20.0,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  club,
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20.0),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEventsList(AppUser? user) {
    if (widget.initialEvents != null) {
      return _buildEventCards(widget.initialEvents!);
    }

    final fs = _getFirestoreService();
    if (user != null && !_signedOut && fs != null) {
      return StreamBuilder<List<Event>>(
        stream: fs.streamEventsCreatedBy(user.id),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final names = snapshot.data!.map((e) => e.title).toList();
            return _buildEventCards(names);
          }
          return _buildEventCards(_fallbackEvents);
        },
      );
    }

    return _buildEventCards(_fallbackEvents);
  }

  Widget _buildEventCards(List<String> events) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No events yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: events.map((event) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10.0),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34.0,
                height: 34.0,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Icon(
                  Icons.event_rounded,
                  color: Colors.purple,
                  size: 20.0,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  event,
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20.0),
            ],
          ),
        );
      }).toList(),
    );
  }
}
