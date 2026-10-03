import '../models/app_user.dart';
import '../models/calendar_entry.dart';
import '../models/event.dart';
import '../models/organization.dart';
import '../services/firestore_service.dart';

/// Fills Firestore with LABELED test data so it's obvious what each
/// document is for when testing (e.g. "User A's Club", "User E's Event").
///
/// Test users and what each one is for:
///   User A - owner of User A's Club
///   User B - owner of User B's Club, AND admin in User A's Club
///   User C - regular member of User A's Club, approved member of User B's Club
///   User D - PENDING member of User B's Club (waiting for approval)
///   User E - in no clubs; hosts their own event and RSVPs to others
///
/// HOW TO RUN IT (one time):
///   1. Delete the old users / organizations / events collections in the
///      Firebase console first, so old and new test data don't mix.
///   2. In main.dart, add `import 'dev/seed_data.dart';` at the top, and
///      `await seedSampleData();` right after `await Firebase.initializeApp(...)`.
///   3. Run the app once, check the Firebase console, then REMOVE those
///      lines so it doesn't create duplicates every launch.
///
/// Note: these test users are profile documents only, not real login
/// accounts, so you can't log in as them. Real users come from sign up.
Future<void> seedSampleData() async {
  final db = FirestoreService();

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------
  AppUser testUser(String letter, String role) => AppUser(
        id: 'test_user_${letter.toLowerCase()}',
        email: 'user${letter.toLowerCase()}@test.com',
        username: 'user_${letter.toLowerCase()}',
        displayName: 'User $letter',
        firstName: 'User',
        lastName: letter,
        bio: 'TEST USER: $role',
        major: 'Test Major',
        gradYear: 2028,
        interests: ['testing'],
      );

  final userA = testUser('A', 'Owner of User A\'s Club');
  final userB = testUser(
      'B', 'Owner of User B\'s Club, admin in User A\'s Club');
  final userC = testUser(
      'C', 'Member of User A\'s Club and User B\'s Club');
  final userD = testUser('D', 'Pending member of User B\'s Club');
  final userE = testUser('E', 'In no clubs; hosts own event, RSVPs to others');

  for (final u in [userA, userB, userC, userD, userE]) {
    await db.createUserProfile(u);
  }

  // ---------------------------------------------------------------------------
  // Clubs
  // ---------------------------------------------------------------------------
  final clubAId = await db.createOrganization(
    Organization(
      id: '', // ignored; Firestore picks the ID
      name: 'User A\'s Club',
      ownerId: userA.id,
      description: 'TEST CLUB: Open to join. Owner: User A. '
          'Admin: User B. Member: User C.',
      category: 'Test Category',
      tags: ['test', 'open'],
      contactEmail: 'usera@test.com',
      socialLinks: {'instagram': 'https://instagram.com/test_club_a'},
      meetingInfo: {
        'day': 'Monday',
        'time': '6:00 PM',
        'location': 'Test Room A',
      },
      requiresApproval: false,
    ),
    userA,
  );

  final clubBId = await db.createOrganization(
    Organization(
      id: '',
      name: 'User B\'s Club',
      ownerId: userB.id,
      description: 'TEST CLUB: Requires approval to join. Owner: User B. '
          'Member: User C (approved). Pending: User D.',
      category: 'Test Category',
      tags: ['test', 'approval-required'],
      contactEmail: 'userb@test.com',
      meetingInfo: {
        'day': 'Wednesday',
        'time': '5:00 PM',
        'location': 'Test Room B',
      },
      requiresApproval: true,
    ),
    userB,
  );

  final clubA = (await db.getOrganization(clubAId))!;
  final clubB = (await db.getOrganization(clubBId))!;

  // User A's Club: User B joins and is promoted to admin; User C joins.
  await db.joinOrganization(clubA, userB);
  await db.setMemberRole(clubAId, userB.id, OrgRole.admin);
  await db.joinOrganization(clubA, userC);

  // User B's Club requires approval: User C is approved, User D stays pending.
  await db.joinOrganization(clubB, userC);
  await db.approveMember(clubBId, userC.id);
  await db.joinOrganization(clubB, userD);

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------
  final now = DateTime.now();
  DateTime daysFromNow(int days, int hour) =>
      DateTime(now.year, now.month, now.day + days, hour);

  final eventAId = await db.createEvent(Event(
    id: '',
    title: 'User A\'s Event',
    description: 'TEST EVENT: Public event for User A\'s Club. '
        'Going: A, B, C. Interested: E.',
    category: 'Test Category',
    tags: ['test', 'public'],
    organizationId: clubAId,
    organizationName: clubA.name,
    createdBy: userA.id,
    hostIds: [userA.id, userB.id],
    startTime: daysFromNow(7, 18),
    endTime: daysFromNow(7, 20),
    location: EventLocation(name: 'Test Room A', address: '123 Test St'),
    capacity: 30,
  ));

  final eventBId = await db.createEvent(Event(
    id: '',
    title: 'User B\'s Members-Only Event',
    description: 'TEST EVENT: Members-only event for User B\'s Club. '
        'Going: B, C.',
    category: 'Test Category',
    tags: ['test', 'members-only'],
    organizationId: clubBId,
    organizationName: clubB.name,
    createdBy: userB.id,
    hostIds: [userB.id],
    startTime: daysFromNow(5, 17),
    endTime: daysFromNow(5, 19),
    location: EventLocation(name: 'Test Room B'),
    visibility: EventVisibility.membersOnly,
  ));

  final cancelledId = await db.createEvent(Event(
    id: '',
    title: 'User A\'s Cancelled Event',
    description: 'TEST EVENT: This event was cancelled.',
    category: 'Test Category',
    tags: ['test', 'cancelled'],
    organizationId: clubAId,
    organizationName: clubA.name,
    createdBy: userA.id,
    hostIds: [userA.id],
    startTime: daysFromNow(12, 18),
    endTime: daysFromNow(12, 19),
    location: EventLocation(name: 'Test Room A'),
  ));
  await db.cancelEvent(cancelledId);

  final eventEId = await db.createEvent(Event(
    id: '',
    title: 'User E\'s Event (No Club, Virtual)',
    description: 'TEST EVENT: Hosted by a user without a club. '
        'Going: E. Not going: A.',
    category: 'Test Category',
    tags: ['test', 'virtual', 'no-club'],
    createdBy: userE.id,
    hostIds: [userE.id],
    startTime: daysFromNow(9, 19),
    endTime: daysFromNow(9, 21),
    location: EventLocation(
      name: 'Online',
      isVirtual: true,
      meetingUrl: 'https://example.com/test-meeting',
    ),
  ));

  final pastId = await db.createEvent(Event(
    id: '',
    title: 'User C\'s Past Event',
    description: 'TEST EVENT: Already happened (completed). Going: C.',
    category: 'Test Category',
    tags: ['test', 'past'],
    createdBy: userC.id,
    hostIds: [userC.id],
    startTime: daysFromNow(-7, 15),
    endTime: daysFromNow(-7, 16),
    location: EventLocation(name: 'Test Room C'),
    status: EventStatus.completed,
  ));

  // ---------------------------------------------------------------------------
  // RSVPs (these also add calendar entries automatically)
  // ---------------------------------------------------------------------------
  final eventA = (await db.getEvent(eventAId))!;
  await db.rsvp(eventA, userA, RsvpStatus.going);
  await db.rsvp(eventA, userB, RsvpStatus.going);
  await db.rsvp(eventA, userC, RsvpStatus.going);
  await db.rsvp(eventA, userE, RsvpStatus.interested);

  final eventB = (await db.getEvent(eventBId))!;
  await db.rsvp(eventB, userB, RsvpStatus.going);
  await db.rsvp(eventB, userC, RsvpStatus.going);

  final eventE = (await db.getEvent(eventEId))!;
  await db.rsvp(eventE, userE, RsvpStatus.going);
  await db.rsvp(eventE, userA, RsvpStatus.notGoing);

  final pastEvent = (await db.getEvent(pastId))!;
  await db.rsvp(pastEvent, userC, RsvpStatus.going);

  // ---------------------------------------------------------------------------
  // Personal calendar entry (not tied to any event)
  // ---------------------------------------------------------------------------
  await db.addPersonalCalendarEntry(
    userC.id,
    CalendarEntry(
      id: '',
      title: 'User C\'s Personal Reminder',
      startTime: daysFromNow(3, 12),
      endTime: daysFromNow(3, 13),
      type: CalendarEntryType.personal,
      reminderMinutesBefore: 30,
      color: '#4A90E2',
    ),
  );
}
