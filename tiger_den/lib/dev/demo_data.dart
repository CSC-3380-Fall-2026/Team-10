import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/event.dart';
import '../models/organization.dart';
import '../services/firestore_service.dart';
import '../services/search_service.dart';

/// Demo content for the class demo, built around ONE real login account
/// (testuser1@tigerden.dev) so the whole demo runs on one device.
///
/// What the demo account ends up with:
///   - OWNS "Tiger Photography Guild" (needs approval; has a pending request)
///   - Is a regular MEMBER of "LSU Running Club"
///   - Is NOT in "Tiger Chess Club" yet, so it can be joined live in the demo
///   - Created and is going to "Golden Hour Photo Walk" and
///     "Finals Study Session", and is going to "Lakeside 5K Group Run"
///   - Has NOT RSVP'd to "Friday Night Blitz" (3 going), so it can RSVP live
///
/// Everything is also added to search. Event dates are set relative to
/// today, so running it again moves the events back into "this week"
/// instead of making duplicates. Run it again the day before the demo.
///
/// The other people (Jordan, Maya, Chris) are profiles only, not logins.
class DemoData {
  DemoData({FirestoreService? firestoreService})
      : _db = firestoreService ?? FirestoreService();

  final FirestoreService _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String chessClubName = 'Tiger Chess Club';
  static const String photoClubName = 'Tiger Photography Guild';
  static const String runningClubName = 'LSU Running Club';
  static const String blitzTitle = 'Friday Night Blitz';

  /// Creates (or refreshes) all demo content for the user [me].
  /// [log] is called with a line of progress text after each step.
  Future<void> createOrRefresh(AppUser me, void Function(String) log) async {
    // People ---------------------------------------------------------------
    final AppUser jordan = await _profile(
        'demo_jordan', 'Jordan', 'Lee', 'President of Tiger Chess Club');
    final AppUser maya = await _profile(
        'demo_maya', 'Maya', 'Patel', 'Runner, photographer, chess fan');
    final AppUser chris =
        await _profile('demo_chris', 'Chris', 'Nguyen', 'Freshman, CS major');
    log('People ready: Jordan Lee, Maya Patel, Chris Nguyen');

    // Clubs ----------------------------------------------------------------
    final Organization chess = await _club(
      Organization(
        id: '',
        name: chessClubName,
        ownerId: jordan.id,
        description: 'Casual and competitive chess for every skill level. '
            'Drop in for blitz, lessons, and weekend tournaments. '
            'Boards provided!',
        category: 'Hobby & Interest',
        tags: <String>['Traditional/Analog/Physical Games', 'Social', 'On Campus'],
        contactEmail: 'chess@tigerden.dev',
        socialLinks: <String, String>{'instagram': '@lsutigerchess'},
        meetingInfo: <String, String>{
          'day': 'Friday',
          'time': '7:00 PM',
          'location': 'Student Union, Room 214',
        },
        requiresApproval: false,
      ),
      jordan,
    );
    await _db.joinOrganization(chess, maya);
    await _db.joinOrganization(chess, chris);
    log('Club ready: $chessClubName (open, owner Jordan)');

    final Organization photo = await _club(
      Organization(
        id: '',
        name: photoClubName,
        ownerId: me.id,
        description: 'Students who love taking pictures. Photo walks around '
            'campus, editing workshops, and a gallery show every spring.',
        category: 'Arts & Performance',
        tags: <String>['Visual Arts', 'The Outdoors and Nature', 'Workshop'],
        contactEmail: 'photo@tigerden.dev',
        meetingInfo: <String, String>{
          'day': 'Wednesday',
          'time': '5:30 PM',
          'location': 'Art Building, Room 102',
        },
        requiresApproval: true,
      ),
      me,
    );
    await _db.joinOrganization(photo, maya);
    await _db.approveMember(photo.id, maya.id);
    await _db.joinOrganization(photo, chris); // stays pending
    log('Club ready: $photoClubName (approval needed, owner you, '
        'Chris pending)');

    final Organization running = await _club(
      Organization(
        id: '',
        name: runningClubName,
        ownerId: maya.id,
        description: 'Group runs around the LSU Lakes for all paces. '
            'Nobody gets left behind.',
        category: 'Sports & Recreation',
        tags: <String>['Physical Activity', 'Individual Sport',
            'Wellness and Health'],
        contactEmail: 'run@tigerden.dev',
        meetingInfo: <String, String>{
          'day': 'Tuesday',
          'time': '7:00 AM',
          'location': 'University Lake, by the boathouse',
        },
        requiresApproval: false,
      ),
      maya,
    );
    await _db.joinOrganization(running, me);
    await _db.joinOrganization(running, chris);
    log('Club ready: $runningClubName (you are a member)');

    // Events ---------------------------------------------------------------
    final DateTime today = DateTime.now();
    DateTime at(int daysFromToday, int hour, [int minute = 0]) =>
        DateTime(today.year, today.month, today.day + daysFromToday, hour,
            minute);

    // The next Friday (today if it's Friday and the event hasn't started)
    int daysToFriday = (DateTime.friday - today.weekday) % 7;
    if (daysToFriday == 0 && today.hour >= 19) daysToFriday = 7;

    final Event blitz = await _event(Event(
      id: '',
      title: blitzTitle,
      description: 'Five-minute blitz games all night. Beginners welcome, '
          'we\'ll pair you with someone your level. Pizza at 8!',
      category: 'official',
      tags: <String>['Traditional/Analog/Physical Games', 'Social',
          'On Campus'],
      organizationId: chess.id,
      organizationName: chess.name,
      createdBy: jordan.id,
      hostIds: <String>[jordan.id],
      startTime: at(daysToFriday, 19),
      endTime: at(daysToFriday, 21),
      location: EventLocation(
          name: 'Student Union, Room 214', address: 'LSU Student Union'),
      capacity: 32,
    ));
    await _db.rsvp(blitz, jordan, RsvpStatus.going);
    await _db.rsvp(blitz, maya, RsvpStatus.going);
    await _db.rsvp(blitz, chris, RsvpStatus.going);
    log('Event ready: $blitzTitle (3 going, you are not RSVP\'d)');

    final Event photoWalk = await _event(Event(
      id: '',
      title: 'Golden Hour Photo Walk',
      description: 'Bring any camera (phones count!). We\'ll walk from the '
          'Quad to the Memorial Tower and shoot the sunset.',
      category: 'official',
      tags: <String>['Visual Arts', 'The Outdoors and Nature', 'On Campus'],
      organizationId: photo.id,
      organizationName: photo.name,
      createdBy: me.id,
      hostIds: <String>[me.id],
      startTime: at(2, 16, 30),
      endTime: at(2, 18),
      location: EventLocation(name: 'The Quad', address: 'LSU Quad'),
      capacity: 20,
    ));
    await _db.rsvp(photoWalk, me, RsvpStatus.going);
    await _db.rsvp(photoWalk, maya, RsvpStatus.going);
    log('Event ready: Golden Hour Photo Walk (you created it and are going)');

    final Event run = await _event(Event(
      id: '',
      title: 'Lakeside 5K Group Run',
      description: 'An easy-paced 5K loop around University Lake. '
          'Coffee afterward for anyone who wants it.',
      category: 'official',
      tags: <String>['Physical Activity', 'The Outdoors and Nature'],
      organizationId: running.id,
      organizationName: running.name,
      createdBy: maya.id,
      hostIds: <String>[maya.id],
      startTime: at(1, 7),
      endTime: at(1, 8),
      location: EventLocation(
          name: 'University Lake Boathouse', address: 'University Lake'),
    ));
    await _db.rsvp(run, me, RsvpStatus.going);
    await _db.rsvp(run, maya, RsvpStatus.going);
    await _db.rsvp(run, chris, RsvpStatus.going);
    log('Event ready: Lakeside 5K Group Run (you are going)');

    final Event study = await _event(Event(
      id: '',
      title: 'Finals Study Session',
      description: 'Open study group for anyone with finals coming up. '
          'Grab a table on the 2nd floor and bring snacks to share.',
      category: 'casual',
      tags: <String>['Academic', 'For Undergraduate Students', 'On Campus'],
      createdBy: me.id,
      hostIds: <String>[me.id],
      startTime: at(3, 18),
      endTime: at(3, 21),
      location: EventLocation(
          name: 'Middleton Library, 2nd Floor', address: 'Middleton Library'),
    ));
    await _db.rsvp(study, me, RsvpStatus.going);
    log('Event ready: Finals Study Session (casual, you created it)');

    // Search ---------------------------------------------------------------
    final int indexed = await _addToSearch(
      <Organization>[chess, photo, running],
      <Event>[blitz, photoWalk, run, study],
    );
    log('Added $indexed of 7 items to search');
  }

  /// Undoes the two things done live in the demo (joining Tiger Chess
  /// Club and RSVPing to Friday Night Blitz) so the demo can be practiced
  /// again.
  Future<void> resetLiveSteps(String myUid, void Function(String) log) async {
    final String? chessId = await _findId('organizations', 'name', chessClubName);
    if (chessId != null) {
      await _db.leaveOrganization(chessId, myUid);
      log('You are no longer in $chessClubName');
    } else {
      log('$chessClubName not found. Create the demo data first.');
    }
    final String? blitzId = await _findId('events', 'title', blitzTitle);
    if (blitzId != null) {
      await _db.cancelRsvp(blitzId, myUid);
      log('Your RSVP to $blitzTitle was removed');
    } else {
      log('$blitzTitle not found. Create the demo data first.');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// A profile-only person (no login). Made once, then reused.
  Future<AppUser> _profile(
      String id, String first, String last, String bio) async {
    final AppUser? existing = await _db.getUser(id);
    if (existing != null) return existing;
    final AppUser user = AppUser(
      id: id,
      email: '${first.toLowerCase()}@tigerden.dev',
      username: '${first.toLowerCase()}_${last.toLowerCase()}',
      displayName: '$first $last',
      firstName: first,
      lastName: last,
      bio: bio,
    );
    await _db.createUserProfile(user);
    return user;
  }

  /// Finds a club by name, or creates it with [owner] as owner.
  Future<Organization> _club(Organization club, AppUser owner) async {
    final String id = await _findId('organizations', 'name', club.name) ??
        await _db.createOrganization(club, owner);
    return (await _db.getOrganization(id))!;
  }

  /// Finds an event by title and moves it to the new dates, or creates it.
  Future<Event> _event(Event event) async {
    final String? existingId = await _findId('events', 'title', event.title);
    final String id;
    if (existingId != null) {
      id = existingId;
      await _db.updateEvent(id, <String, dynamic>{
        'startTime': Timestamp.fromDate(event.startTime),
        'endTime': Timestamp.fromDate(event.endTime),
        'status': EventStatus.scheduled.name,
      });
    } else {
      id = await _db.createEvent(event);
    }
    return (await _db.getEvent(id))!;
  }

  Future<String?> _findId(String collection, String field, String value) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(collection)
        .where(field, isEqualTo: value)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  /// Adds every club and event to search. Returns how many worked.
  Future<int> _addToSearch(
      List<Organization> clubs, List<Event> events) async {
    final SearchService search = SearchService();
    int count = 0;
    for (final Organization club in clubs) {
      final String id = await search.createIndex(
          'club', club.name, club.description, club.id, club.tags, 'official');
      if (id.isNotEmpty) count++;
    }
    for (final Event event in events) {
      final String id = await search.createIndex('event', event.title,
          event.description, event.id, event.tags, event.category);
      if (id.isNotEmpty) count++;
    }
    return count;
  }
}
