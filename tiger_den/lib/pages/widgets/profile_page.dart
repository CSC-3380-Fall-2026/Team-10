import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../base_designs/sitewide/design_main.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../models/organization.dart';
import '../../services/auth_service.dart';
import '../../services/current_user_service.dart';
import '../../services/firestore_service.dart';
import '../entire_screen/navigation_bar.dart';
import '../entire_screen/search_page.dart';
import 'club_Editing.dart';
import 'event_editing.dart';
import 'login_page.dart';

/// Profile Page for Tiger Den, based off wireframes.
///
/// Shows the logged-in user's profile (from CurrentUserService), their clubs,
/// and the events they created, all loaded live from Firestore.
///   - Tap a club you own/admin to edit it; tap any other club to leave it
///     (or cancel a pending join request).
///   - Tap an event to edit it.
///   - Sign Out logs out of Firebase.
///
/// Pass [currentUserId] to show a specific user's profile instead of the
/// logged-in user (used by lib/dev/profile_test_main.dart). The initialX
/// parameters show fixed data with no database (for previews and tests).
/// TODO: find out a way to fix transition between pages
class ProfilePage extends StatefulWidget {
  final AppUser? initialUser;
  final List<String>? initialClubs;
  final List<String>? initialEvents;
  final AuthService? authService;
  final FirestoreService? firestoreService;
  final VoidCallback? onSignOut;

  /// Whose profile to show. Null = the logged-in user.
  final String? currentUserId;

  const ProfilePage({
    super.key,
    this.initialUser,
    this.initialClubs,
    this.initialEvents,
    this.authService,
    this.firestoreService,
    this.onSignOut,
    this.currentUserId,
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
  /// Fetches the firestore service
  FirestoreService? _getFirestoreService() {
    if (widget.firestoreService != null) return widget.firestoreService;
    try {
      return _firestoreServiceInstance ??= FirestoreService();
    } catch (_) {
      return null;
    }
  }
  bool _signedOut = false;

  /// The logged-in user's profile service (null if Firebase isn't set up,
  /// e.g. in widget tests).
  CurrentUserService? _currentUserService;

  /// Live profile for [ProfilePage.currentUserId] (test/preview mode only)
  Stream<AppUser?>? _userStream;

  /// The user whose clubs/events streams are open. The streams are only
  /// replaced when this changes, NOT on every redraw, so the page doesn't
  /// keep re-reading the database.
  String? _streamsUid;
  Stream<List<Membership>>? _membershipsStream;
  Stream<List<Event>>? _eventsStream;

  @override
  void initState() {
    super.initState();
    final String? fixedUid = widget.currentUserId;
    if (fixedUid != null) {
      _userStream = _getFirestoreService()?.streamUser(fixedUid);
    } else if (widget.initialUser == null) {
      try {
        _currentUserService = CurrentUserService.instance;
      } catch (_) {
        _currentUserService = null;
      }
    }
  }

  /// Opens the clubs/events streams for [uid], once per user
  void _connectListsFor(String uid) {
    if (_streamsUid == uid) return;
    final FirestoreService? fs = _getFirestoreService();
    _streamsUid = uid;
    _membershipsStream = fs?.streamMyMemberships(uid);
    _eventsStream = fs?.streamEventsCreatedBy(uid);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.purple),
    );
  }

  // Sign-out prompt
  Future<void> _handleSignOut() async {
    final bool? shouldSignOut = await _confirm(
      'Are you sure you want to sign out?',
    );

    if (shouldSignOut == true) {
      try {
        final AuthService? auth = _getAuthService();
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
        _showMessage('Signed out successfully.');
        widget.onSignOut?.call();
      }
    }
  }

  /// A Yes/No dialog in the same style as the sign-out prompt
  Future<bool?> _confirm(String question) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple,
                side: const BorderSide(color: Colors.purple, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
  }

  // Club and event buttons

  /// Opens [form] full-screen with a back arrow
  void _openPage(String title, Widget form) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: form,
            ),
          ),
        ),
      ),
    );
  }

  /// Owners/admins edit the club; members can leave; pending can cancel.
  Future<void> _onClubTapped(AppUser user, Membership membership) async {
    final bool isPending = membership.status == MemberStatus.pending;
    final bool canEdit = !isPending &&
        (membership.role == OrgRole.owner || membership.role == OrgRole.admin);

    if (canEdit) {
      _openPage(
        'Edit: ${membership.orgName}',
        ClubEditForm(orgId: membership.orgId, currentUserId: user.id),
      );
      return;
    }

    final String action = isPending ? 'Cancel join request' : 'Leave club';
    final bool? chosen = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                membership.orgName,
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                isPending
                    ? 'Your request to join is waiting for approval.'
                    : 'You are a member of this club.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16.0),
              OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700, width: 1.5),
                ),
                child: Text(action),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != true || !mounted) return;

    final bool? confirmed = await _confirm(
      isPending
          ? 'Cancel your request to join ${membership.orgName}?'
          : 'Leave ${membership.orgName}?',
    );
    if (confirmed != true) return;

    final FirestoreService? fs = _getFirestoreService();
    if (fs == null) return;
    try {
      await fs.leaveOrganization(membership.orgId, user.id);
      _showMessage(isPending
          ? 'Join request cancelled.'
          : 'You left ${membership.orgName}.');
    } catch (e) {
      _showMessage('Could not leave the club: $e');
    }
  }

  /// Opens the edit form for an event created by the user.
  void _onEventTapped(AppUser user, Event event) {
    _openPage(
      'Edit: ${event.title}',
      EventEditForm(eventId: event.id, currentUserId: user.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    final AppUser? widgeInitialU = widget.initialUser;
    if (_signedOut) {
      body = _buildMessageOut('You are signed out.');
    } else if (widgeInitialU != null) {
      body = _buildProfile(widgeInitialU);
    } else if (_userStream != null) {
      
      body = StreamBuilder<AppUser?>(
        stream: _userStream,
        builder: (BuildContext context, AsyncSnapshot<AppUser?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final AppUser? user = snapshot.data;
          return user == null
              ? _buildMessageOut('This profile could not be found.')
              : _buildProfile(user);
        },
      );
    } else if (_currentUserService != null) {
      final CurrentUserService me = _currentUserService!;
      body = ListenableBuilder(
        listenable: me,
        builder: (BuildContext context, Widget? child) {
          if (me.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final AppUser? user = me.user;
          if (user != null) return _buildProfile(user);
          final String? meUid = me.uid;
          return _buildMessageOut(meUid == null
              ? 'Log in to see your profile.'
              : 'Your profile could not be found.');
        },
      );
    } else {
      body = _buildMessageOut('Log in to see your profile.');
    }

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.purple,
        backgroundColor: Colors.grey,
        title: const Text('Tiger Den Profile'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const SearchPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: const AppNavigationBar(currentIndex: 2),
    );
  }

  ///builds message for error and has a button that signs user out if applicable and then takes them to the login screen
  Widget _buildMessageOut(String text) {
    return Column(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.0, color: Colors.grey.shade700),
            ),
          ),
        ),
        _buildOutButton(),
      ]
    );
  }
  /// Button for if profile fails to load;
  Widget _buildOutButton(){
    return Column(
      children: [
        Center(
          child: Text(
            "If you see the above message and do not expect it, try clicking this button and logging in again.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.0, color: Colors.grey.shade700)
            )
          ),
        SizedBox(height: context.style.spaceMedium),
        SizedBox(
          width: double.infinity,
          height: 48.0,
          child: ElevatedButton(
            onPressed: _handleOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: Text(
              'Back to Login',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        )
      ]
    );
  }
  /// Handles signing out if there is an error when loading the profile
  Future<void>_handleOut() async{
    bool success = true;
      try {
        final AuthService? auth = _getAuthService();
        if (auth != null) {
          await auth.logOut();
        }
      } catch (e) {
        debugPrint('Sign out notice: $e');
        _showMessage('Sign out unsuccessful. Try Logging in again if possible anyway.');
        success = false;
      }

      if (mounted) {
        setState(() {
          _signedOut = true;
        });
        if(success){
          _showMessage('Signed out successfully.');
        }
        widget.onSignOut?.call();
      }
    
    if (mounted){
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 150),
        ),
      );
    }
  }

  Widget _buildProfile(AppUser user) {
    final String username =
        user.username.isNotEmpty ? '@${user.username}' : user.email;

    final String fullName = '${user.firstName} ${user.lastName}'.trim();
    final String displayName = user.displayName.isNotEmpty
        ? user.displayName
        : (fullName.isNotEmpty ? fullName : user.email);

    final String bio = user.bio.isNotEmpty ? user.bio : 'No bio yet.';

    final String? photoUrl = user.profilePhotoUrl;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // User Header (Slide 5: Avatar on left, Username and Name on right)
          Row(
            children: <Widget>[
              _buildAvatar(photoUrl, displayName),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
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
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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

          _buildSignOutButton(),

          const SizedBox(height: 16.0),
        ],
      ),
    );
  }
  Widget _buildSignOutButton(){
    return SizedBox(
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
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) =>
                        _avatarFallback(displayName),
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
              style: const TextStyle(
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

  // ---------------------------------------------------------------------------
  // Clubs and events lists
  // ---------------------------------------------------------------------------

  Widget _buildClubsList(AppUser user) {
    if (widget.initialClubs != null) {
      return _buildCards(
        <_CardData>[
          for (final String name in widget.initialClubs!)
            _CardData(title: name),
        ],
        icon: Icons.groups_rounded,
        emptyText: 'No clubs joined yet.',
      );
    }

    _connectListsFor(user.id);
    final Stream<List<Membership>>? stream = _membershipsStream;
    if (stream == null) return _buildListMessage('No clubs joined yet.');

    return StreamBuilder<List<Membership>>(
      stream: stream,
      builder: (BuildContext context,
          AsyncSnapshot<List<Membership>> snapshot) {
        if (snapshot.hasError) {
          return _buildListMessage('Could not load clubs.');
        }
        if (!snapshot.hasData) return _buildListLoading();
        final List<Membership> memberships =
            List<Membership>.from(snapshot.data!)
              ..sort((Membership a, Membership b) =>
                  a.orgName.toLowerCase().compareTo(b.orgName.toLowerCase()));
        return _buildCards(
          <_CardData>[
            for (final Membership m in memberships)
              _CardData(
                title: m.orgName,
                tag: _clubTag(m),
                onTap: () => _onClubTapped(user, m),
              ),
          ],
          icon: Icons.groups_rounded,
          emptyText: 'No clubs joined yet.',
        );
      },
    );
  }

  /// "Owner" / "Admin" / "Pending", or null for regular members
  String? _clubTag(Membership membership) {
    if (membership.status == MemberStatus.pending) return 'Pending';
    if (membership.role == OrgRole.owner) return 'Owner';
    if (membership.role == OrgRole.admin) return 'Admin';
    return null;
  }

  Widget _buildEventsList(AppUser user) {
    if (widget.initialEvents != null) {
      return _buildCards(
        <_CardData>[
          for (final String title in widget.initialEvents!)
            _CardData(title: title),
        ],
        icon: Icons.event_rounded,
        emptyText: 'No events yet.',
      );
    }

    _connectListsFor(user.id);
    final Stream<List<Event>>? stream = _eventsStream;
    if (stream == null) return _buildListMessage('No events yet.');

    return StreamBuilder<List<Event>>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<List<Event>> snapshot) {
        if (snapshot.hasError) {
          return _buildListMessage('Could not load events.');
        }
        if (!snapshot.hasData) return _buildListLoading();
        return _buildCards(
          <_CardData>[
            for (final Event e in snapshot.data!)
              _CardData(
                title: e.title,
                subtitle: _formatDate(e.startTime),
                tag: e.status == EventStatus.cancelled ? 'Cancelled' : null,
                onTap: () => _onEventTapped(user, e),
              ),
          ],
          icon: Icons.event_rounded,
          emptyText: 'No events yet.',
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final int hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour < 12 ? 'AM' : 'PM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} · '
        '$hour:$minute $period';
  }

  Widget _buildListLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildListMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }

  /// The club/event cards (same look as the skeleton), now tappable
  Widget _buildCards(
    List<_CardData> cards, {
    required IconData icon,
    required String emptyText,
  }) {
    if (cards.isEmpty) return _buildListMessage(emptyText);

    return Column(
      children: <Widget>[
        for (final _CardData card in cards)
          Container(
            margin: const EdgeInsets.only(bottom: 10.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12.0),
                onTap: card.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 34.0,
                        height: 34.0,
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.purple,
                          size: 20.0,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              card.title,
                              style: const TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (card.subtitle != null)
                              Text(
                                card.subtitle!,
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (card.tag != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8.0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            card.tag!,
                            style: const TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      Icon(Icons.chevron_right,
                          color: Colors.grey.shade400, size: 20.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// What one club/event card shows, and what tapping it does
class _CardData {
  const _CardData({
    required this.title,
    this.subtitle,
    this.tag,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? tag;
  final FutureOr<void> Function()? onTap;
}
