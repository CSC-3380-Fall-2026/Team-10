import 'package:flutter/material.dart';

import '../../base_designs/sitewide/design_main.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/current_user_service.dart';
import '../../services/firestore_service.dart';
import '../../services/session_service.dart';

/// Shows one event's details and lets the logged-in user RSVP.
///
/// Open it from anywhere with:
///   EventDetailsPage.open(context, eventId);
///
/// RSVPing ("Going") adds the event to the user's calendar and updates the
/// "X going" count; "Cancel RSVP" removes both. The page updates live.
///
/// By default it uses the logged-in user (SessionService). Pass
/// [currentUserId] to act as a specific user instead (used for testing).
class EventDetailsPage extends StatefulWidget {
  const EventDetailsPage({
    super.key,
    required this.eventId,
    this.currentUserId,
    this.firestoreService,
  });

  final String eventId;
  final String? currentUserId;
  final FirestoreService? firestoreService;

  /// Opens the details page for [eventId] on top of the current screen.
  static Future<void> open(BuildContext context, String eventId,
      {String? currentUserId}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EventDetailsPage(
          eventId: eventId,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  late final FirestoreService _db;

  /// The user who is viewing (and RSVPing), or null if nobody is logged in
  String? _uid;

  // Created once (not in build) so the page doesn't keep re-reading the
  // database every time it redraws. Both update live.
  late final Stream<Event?> _eventStream;
  Stream<Attendee?>? _myRsvpStream;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _db = widget.firestoreService ?? FirestoreService();
    _uid = widget.currentUserId ?? SessionService.instance.currentUid;
    _eventStream = _db.streamEvent(widget.eventId);
    final String? uid = _uid;
    if (uid != null) {
      _myRsvpStream = _db.streamMyRsvp(widget.eventId, uid);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// The viewer's profile, needed to RSVP (it saves their display name)
  Future<AppUser?> _loadViewer(String uid) async {
    final AppUser? loggedIn = CurrentUserService.instance.user;
    if (loggedIn != null && loggedIn.id == uid) return loggedIn;
    return _db.getUser(uid);
  }

  Future<void> _rsvpGoing(Event event) async {
    final String? uid = _uid;
    if (uid == null || _busy) return;
    setState(() => _busy = true);
    try {
      final AppUser? user = await _loadViewer(uid);
      if (user == null) {
        _showMessage('Your profile could not be loaded, so you can\'t RSVP.');
        return;
      }
      await _db.rsvp(event, user, RsvpStatus.going);
      _showMessage('You\'re going! It\'s been added to your calendar.');
    } catch (e) {
      _showMessage('Could not RSVP: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelRsvp(Event event) async {
    final String? uid = _uid;
    if (uid == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _db.cancelRsvp(event.id, uid);
      _showMessage('RSVP cancelled. It\'s been removed from your calendar.');
    } catch (e) {
      _showMessage('Could not cancel your RSVP: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  static const List<String> _weekdays = <String>[
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];
  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDay(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} '
      '${date.day}, ${date.year}';

  String _formatTime(DateTime date) {
    final int hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// e.g. "Friday, Nov 27, 2026 · 6:00 PM – 8:00 PM"
  String _formatWhen(Event event) {
    final DateTime start = event.startTime;
    final DateTime end = event.endTime;
    if (event.allDay) {
      return _sameDay(start, end)
          ? '${_formatDay(start)} · All day'
          : '${_formatDay(start)} – ${_formatDay(end)} · All day';
    }
    if (_sameDay(start, end)) {
      return '${_formatDay(start)} · ${_formatTime(start)} – '
          '${_formatTime(end)}';
    }
    return '${_formatDay(start)} ${_formatTime(start)} – '
        '${_formatDay(end)} ${_formatTime(end)}';
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
        title: const Text('Event Details'),
      ),
      body: StreamBuilder<Event?>(
        stream: _eventStream,
        builder: (BuildContext context, AsyncSnapshot<Event?> snapshot) {
          if (snapshot.hasError) {
            return _buildMessage('Could not load this event.');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final Event? event = snapshot.data;
          if (event == null) {
            return _buildMessage('This event no longer exists.');
          }
          return _buildEvent(context, event);
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

  Widget _buildEvent(BuildContext context, Event event) {
    final AppStyle style = context.style;
    final TextTheme text = Theme.of(context).textTheme;
    final String? imageUrl = event.imageUrl;
    final bool isOfficial = event.category == 'official';

    return SingleChildScrollView(
      padding: EdgeInsets.all(style.spaceMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(style.radius),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object error,
                          StackTrace? stack) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          if (event.status == EventStatus.cancelled)
            _buildBanner(context, 'This event has been cancelled.'),
          SizedBox(height: style.spaceMedium),
          Text(
            event.title,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: style.spaceExtraSmall),
          Wrap(
            spacing: style.spaceSmall,
            runSpacing: style.spaceExtraSmall,
            children: <Widget>[
              _buildChip(isOfficial ? 'Official club event' : 'Student event'),
              if (event.organizationName != null &&
                  event.organizationName!.isNotEmpty)
                _buildChip('Hosted by ${event.organizationName}'),
            ],
          ),
          SizedBox(height: style.spaceMedium),
          _buildInfoRow(Icons.schedule, _formatWhen(event)),
          _buildInfoRow(
            event.location.isVirtual ? Icons.videocam_outlined : Icons.place,
            event.location.isVirtual
                ? 'Online${event.location.meetingUrl != null ? ': ${event.location.meetingUrl}' : ''}'
                : event.location.name,
          ),
          _buildInfoRow(
            Icons.groups,
            event.capacity != null
                ? '${event.attendeeCount} going · ${event.capacity} spots'
                : '${event.attendeeCount} going',
          ),
          SizedBox(height: style.spaceMedium),
          _buildRsvpSection(context, event),
          SizedBox(height: style.spaceLarge),
          if (event.description.isNotEmpty) ...<Widget>[
            Text('About', style: text.titleMedium),
            SizedBox(height: style.spaceExtraSmall),
            Text(event.description, style: text.bodyMedium),
            SizedBox(height: style.spaceMedium),
          ],
          if (event.tags.isNotEmpty) ...<Widget>[
            Text('Tags', style: text.titleMedium),
            SizedBox(height: style.spaceExtraSmall),
            Wrap(
              spacing: style.spaceSmall,
              runSpacing: style.spaceExtraSmall,
              children: <Widget>[
                for (final String tag in event.tags) _buildChip(tag),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBanner(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: context.style.spaceSmall),
      padding: EdgeInsets.all(context.style.spaceSmall),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(context.style.radius),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(text, style: TextStyle(color: Colors.red.shade800)),
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

  /// The RSVP button, or a note explaining why the user can't RSVP
  Widget _buildRsvpSection(BuildContext context, Event event) {
    if (_uid == null) {
      return _buildDisabledButton('Log in to RSVP');
    }
    if (event.status == EventStatus.cancelled) {
      return _buildDisabledButton('This event was cancelled');
    }
    if (event.endTime.isBefore(DateTime.now())) {
      return _buildDisabledButton('This event has ended');
    }

    return StreamBuilder<Attendee?>(
      stream: _myRsvpStream,
      builder: (BuildContext context, AsyncSnapshot<Attendee?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 48.0,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final Attendee? myRsvp = snapshot.data;
        final bool isGoing = myRsvp?.status == RsvpStatus.going;

        if (isGoing) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8.0),
                  Text(
                    'You\'re going. It\'s on your calendar.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              SizedBox(
                height: 48.0,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _cancelRsvp(event),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    side: const BorderSide(color: AppColors.purple, width: 1.5),
                  ),
                  child: Text(_busy ? 'Cancelling...' : 'Cancel RSVP'),
                ),
              ),
            ],
          );
        }

        final int? capacity = event.capacity;
        final bool isFull = capacity != null && event.attendeeCount >= capacity;
        if (isFull) {
          return _buildDisabledButton('This event is full');
        }

        return SizedBox(
          width: double.infinity,
          height: 48.0,
          child: ElevatedButton(
            onPressed: _busy ? null : () => _rsvpGoing(event),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              foregroundColor: AppColors.white,
            ),
            child: Text(_busy ? 'Saving...' : 'RSVP: Going'),
          ),
        );
      },
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
