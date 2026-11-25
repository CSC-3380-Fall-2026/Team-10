import 'package:flutter/material.dart';

import '../../base_designs/sitewide/design_main.dart';
import '../../models/app_user.dart';
import '../../models/organization.dart';
import '../../services/current_user_service.dart';
import '../../services/firestore_service.dart';
import '../../services/session_service.dart';

/// Shows one club's page and lets the logged-in user join or leave it.
///
/// Open it from anywhere with:
///   ClubPage.open(context, orgId);
///
/// "Join" adds the user to the club and to their "My Clubs" list and raises
/// the member count. Clubs that require approval mark the request as
/// "Pending" instead. The page updates live.
///
/// By default it uses the logged-in user (SessionService). Pass
/// [currentUserId] to act as a specific user instead (used for testing).
class ClubPage extends StatefulWidget {
  const ClubPage({
    super.key,
    required this.orgId,
    this.currentUserId,
    this.firestoreService,
  });

  final String orgId;
  final String? currentUserId;
  final FirestoreService? firestoreService;

  /// Opens the page for [orgId] on top of the current screen.
  static Future<void> open(BuildContext context, String orgId,
      {String? currentUserId}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ClubPage(
          orgId: orgId,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> {
  late final FirestoreService _db;

  /// The user who is viewing (and joining), or null if nobody is logged in
  String? _uid;

  // Created once (not in build) so the page doesn't keep re-reading the
  // database every time it redraws. Both update live.
  late final Stream<Organization?> _clubStream;
  Stream<List<Membership>>? _myMembershipsStream;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _db = widget.firestoreService ?? FirestoreService();
    _uid = widget.currentUserId ?? SessionService.instance.currentUid;
    _clubStream = _db.streamOrganization(widget.orgId);
    final String? uid = _uid;
    if (uid != null) {
      _myMembershipsStream = _db.streamMyMemberships(uid);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// The viewer's profile, needed to join (it saves their display name)
  Future<AppUser?> _loadViewer(String uid) async {
    final AppUser? loggedIn = CurrentUserService.instance.user;
    if (loggedIn != null && loggedIn.id == uid) return loggedIn;
    return _db.getUser(uid);
  }

  Future<void> _join(Organization club) async {
    final String? uid = _uid;
    if (uid == null || _busy) return;
    setState(() => _busy = true);
    try {
      final AppUser? user = await _loadViewer(uid);
      if (user == null) {
        _showMessage('Your profile could not be loaded, so you can\'t join.');
        return;
      }
      await _db.joinOrganization(club, user);
      _showMessage(club.requiresApproval
          ? 'Request sent. The club\'s admins will review it.'
          : 'You joined ${club.name}!');
    } catch (e) {
      _showMessage('Could not join the club: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(Organization club, {required bool isPending}) async {
    final String? uid = _uid;
    if (uid == null || _busy) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(isPending
            ? 'Cancel your request to join ${club.name}?'
            : 'Leave ${club.name}?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _db.leaveOrganization(club.id, uid);
      _showMessage(
          isPending ? 'Join request cancelled.' : 'You left ${club.name}.');
    } catch (e) {
      _showMessage('Could not leave the club: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.purple,
        backgroundColor: Colors.grey,
        title: const Text('Club'),
      ),
      body: StreamBuilder<Organization?>(
        stream: _clubStream,
        builder:
            (BuildContext context, AsyncSnapshot<Organization?> snapshot) {
          if (snapshot.hasError) {
            return _buildMessage('Could not load this club.');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final Organization? club = snapshot.data;
          if (club == null) {
            return _buildMessage('This club no longer exists.');
          }
          return _buildClub(context, club);
        },
      ),
    );
  }

  Widget _buildMessage(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildClub(BuildContext context, Organization club) {
    final AppStyle style = context.style;
    final TextTheme text = Theme.of(context).textTheme;

    final String meetingDay = club.meetingInfo['day'] ?? '';
    final String meetingTime = club.meetingInfo['time'] ?? '';
    final String meetingLocation = club.meetingInfo['location'] ?? '';
    final String meetingWhen = <String>[meetingDay, meetingTime]
        .where((String part) => part.isNotEmpty)
        .join(' at ');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(context, club),
          Padding(
            padding: EdgeInsets.all(style.spaceMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: style.spaceSmall,
                  runSpacing: style.spaceExtraSmall,
                  children: <Widget>[
                    if (club.category.isNotEmpty) _buildChip(club.category),
                    _buildChip(club.requiresApproval
                        ? 'Approval to join'
                        : 'Open to join'),
                  ],
                ),
                SizedBox(height: style.spaceMedium),
                _buildInfoRow(
                  Icons.groups,
                  club.memberCount == 1
                      ? '1 member'
                      : '${club.memberCount} members',
                ),
                if (meetingWhen.isNotEmpty)
                  _buildInfoRow(Icons.schedule, 'Meets $meetingWhen'),
                if (meetingLocation.isNotEmpty)
                  _buildInfoRow(Icons.place, meetingLocation),
                if (club.contactEmail != null &&
                    club.contactEmail!.isNotEmpty)
                  _buildInfoRow(Icons.email_outlined, club.contactEmail!),
                for (final MapEntry<String, String> link
                    in club.socialLinks.entries)
                  _buildInfoRow(Icons.link, '${link.key}: ${link.value}'),
                SizedBox(height: style.spaceMedium),
                _buildJoinSection(club),
                SizedBox(height: style.spaceLarge),
                if (club.description.isNotEmpty) ...<Widget>[
                  Text('About', style: text.titleMedium),
                  SizedBox(height: style.spaceExtraSmall),
                  Text(club.description, style: text.bodyMedium),
                  SizedBox(height: style.spaceMedium),
                ],
                if (club.tags.isNotEmpty) ...<Widget>[
                  Text('Tags', style: text.titleMedium),
                  SizedBox(height: style.spaceExtraSmall),
                  Wrap(
                    spacing: style.spaceSmall,
                    runSpacing: style.spaceExtraSmall,
                    children: <Widget>[
                      for (final String tag in club.tags) _buildChip(tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Banner across the top with the logo and name under it
  Widget _buildHeader(BuildContext context, Organization club) {
    final String? bannerUrl = club.bannerUrl;
    final String? logoUrl = club.logoUrl;
    final String firstLetter =
        club.name.isEmpty ? '?' : club.name.substring(0, 1).toUpperCase();

    final Widget fallbackLogo = CircleAvatar(
      radius: 36.0,
      backgroundColor: AppColors.purple,
      child: Text(
        firstLetter,
        style: const TextStyle(
          fontSize: 28.0,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 150.0,
          width: double.infinity,
          child: bannerUrl != null && bannerUrl.isNotEmpty
              ? Image.network(
                  bannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object error,
                          StackTrace? stackTrace) =>
                      Container(color: AppColors.purple.withValues(alpha: 0.2)),
                )
              : Container(color: AppColors.purple.withValues(alpha: 0.2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
          child: Row(
            children: <Widget>[
              logoUrl != null && logoUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        logoUrl,
                        width: 72.0,
                        height: 72.0,
                        fit: BoxFit.cover,
                        errorBuilder: (BuildContext context, Object error,
                                StackTrace? stackTrace) =>
                            fallbackLogo,
                      ),
                    )
                  : fallbackLogo,
              const SizedBox(width: 16.0),
              Expanded(
                child: Text(
                  club.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          color: AppColors.purple,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20.0, color: AppColors.purple),
          const SizedBox(width: 10.0),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  /// The Join button, or the user's current status in this club
  Widget _buildJoinSection(Organization club) {
    final String? uid = _uid;
    final Stream<List<Membership>>? membershipsStream = _myMembershipsStream;
    if (uid == null || membershipsStream == null) {
      return _buildDisabledButton('Log in to join');
    }

    return StreamBuilder<List<Membership>>(
      stream: membershipsStream,
      builder:
          (BuildContext context, AsyncSnapshot<List<Membership>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 48.0,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        Membership? mine;
        for (final Membership membership
            in snapshot.data ?? const <Membership>[]) {
          if (membership.orgId == club.id) {
            mine = membership;
            break;
          }
        }

        // Owners and admins manage the club, so they can't leave from here
        // (leaving would leave the club without them in its admin list).
        if (club.ownerId == uid || mine?.role == OrgRole.owner) {
          return _buildStatusRow(Icons.star, 'You own this club');
        }
        if (club.adminIds.contains(uid) || mine?.role == OrgRole.admin) {
          return _buildStatusRow(Icons.shield, 'You\'re an admin of this club');
        }

        if (mine != null && mine.status == MemberStatus.pending) {
          return _buildStatusWithAction(
            icon: Icons.hourglass_top,
            iconColor: Colors.orange,
            status: 'Request pending. An admin needs to approve it.',
            actionLabel: 'Cancel request',
            onPressed: () => _leave(club, isPending: true),
          );
        }
        if (mine != null) {
          return _buildStatusWithAction(
            icon: Icons.check_circle,
            iconColor: Colors.green,
            status: 'You\'re a member. It\'s in your "My Clubs".',
            actionLabel: 'Leave club',
            onPressed: () => _leave(club, isPending: false),
          );
        }

        return SizedBox(
          width: double.infinity,
          height: 48.0,
          child: ElevatedButton(
            onPressed: _busy ? null : () => _join(club),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              foregroundColor: AppColors.white,
            ),
            child: Text(_busy
                ? 'Saving...'
                : (club.requiresApproval ? 'Request to join' : 'Join')),
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(IconData icon, String status,
      {Color iconColor = AppColors.purple}) {
    return Row(
      children: <Widget>[
        Icon(icon, color: iconColor),
        const SizedBox(width: 8.0),
        Expanded(
          child: Text(
            status,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusWithAction({
    required IconData icon,
    required Color iconColor,
    required String status,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildStatusRow(icon, status, iconColor: iconColor),
        const SizedBox(height: 8.0),
        SizedBox(
          height: 48.0,
          child: OutlinedButton(
            onPressed: _busy ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.purple,
              side: const BorderSide(color: AppColors.purple, width: 1.5),
            ),
            child: Text(_busy ? 'Saving...' : actionLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledButton(String label) {
    return SizedBox(
      width: double.infinity,
      height: 48.0,
      child: ElevatedButton(onPressed: null, child: Text(label)),
    );
  }
}
