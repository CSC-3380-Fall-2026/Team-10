import '../models/app_user.dart';
import '../models/calendar_entry.dart';
import '../models/event.dart';
import '../models/organization.dart';
import '../services/firestore_service.dart';

/// Fills Firestore with sample users, clubs, events, RSVPs, and calendar
/// entries so the frontend has real-looking data to display.
///
/// HOW TO RUN IT (one time):
///   In main.dart, right after `await Firebase.initializeApp(...)`, add:
///       await seedSampleData();
///   Run the app once, check the Firebase Console, then DELETE that line
///   so it doesn't create duplicates every launch.
///
/// Note: these sample users are profile documents only, not real login
/// accounts, so you can't log in as them. Real users come from sign up.
Future<void> seedSampleData() async {
  final db = FirestoreService();

  // ---- Users ---------------------------------------------------------------
  final alex = AppUser(
    id: 'sample_user_alex',
    email: 'alex@example.com',
    username: 'alexr',
    displayName: 'Alex Rivera',
    firstName: 'Alex',
    lastName: 'Rivera',
    bio: 'CS junior. Board games and bad puns.',
    major: 'Computer Science',
    gradYear: 2028,
    interests: ['games', 'tech'],
  );
  final jordan = AppUser(
    id: 'sample_user_jordan',
    email: 'jordan@example.com',
    username: 'jordanl',
    displayName: 'Jordan Lee',
    firstName: 'Jordan',
    lastName: 'Lee',
    bio: 'Runner, photographer, coffee enthusiast.',
    major: 'Biology',
    gradYear: 2027,
    interests: ['fitness', 'photography'],
  );
  await db.createUserProfile(alex);
  await db.createUserProfile(jordan);

  // ---- Organizations -------------------------------------------------------
  final chessClubId = await db.createOrganization(
    Organization(
      id: '', // ignored; Firestore picks the ID
      name: 'Chess Club',
      ownerId: alex.id,
      description: 'Casual and competitive chess for every skill level.',
      category: 'Games',
      tags: ['chess', 'strategy', 'beginner-friendly'],
      contactEmail: 'chessclub@example.com',
      socialLinks: {'instagram': 'https://instagram.com/example_chess'},
      meetingInfo: {
        'day': 'Tuesday',
        'time': '6:00 PM',
        'location': 'Student Union 204',
      },
    ),
    alex,
  );
  final runClubId = await db.createOrganization(
    Organization(
      id: '',
      name: 'Running Club',
      ownerId: jordan.id,
      description: 'Group runs around campus. All paces welcome.',
      category: 'Fitness',
      tags: ['running', 'outdoors'],
      meetingInfo: {
        'day': 'Saturday',
        'time': '7:30 AM',
        'location': 'Rec Center front steps',
      },
    ),
    jordan,
  );

  // Jordan also joins Chess Club.
  final chessClub = (await db.getOrganization(chessClubId))!;
  await db.joinOrganization(chessClub, jordan);

  // ---- Events --------------------------------------------------------------
  final now = DateTime.now();
  DateTime daysFromNow(int days, int hour) =>
      DateTime(now.year, now.month, now.day + days, hour);

  final mixerId = await db.createEvent(Event(
    id: '',
    title: 'Chess Club Welcome Mixer',
    description: 'Meet the club, grab pizza, play a few casual games.',
    category: 'Social',
    tags: ['chess', 'free food'],
    organizationId: chessClubId,
    organizationName: 'Chess Club',
    createdBy: alex.id,
    hostIds: [alex.id],
    startTime: daysFromNow(7, 18),
    endTime: daysFromNow(7, 20),
    location: EventLocation(
      name: 'Student Union 204',
      address: '123 Campus Dr',
    ),
    capacity: 40,
  ));

  await db.createEvent(Event(
    id: '',
    title: 'Saturday 5K Group Run',
    description: 'Easy-pace loop around campus. Meet at the front steps.',
    category: 'Fitness',
    tags: ['running'],
    organizationId: runClubId,
    organizationName: 'Running Club',
    createdBy: jordan.id,
    hostIds: [jordan.id],
    startTime: daysFromNow(3, 7),
    endTime: daysFromNow(3, 8),
    location: EventLocation(name: 'Rec Center front steps'),
  ));

  // An event hosted by a user without a club.
  await db.createEvent(Event(
    id: '',
    title: 'Study Group: Data Structures Final',
    description: 'Online review session. Bring questions!',
    category: 'Academic',
    tags: ['study'],
    createdBy: alex.id,
    hostIds: [alex.id],
    startTime: daysFromNow(10, 19),
    endTime: daysFromNow(10, 21),
    location: EventLocation(
      name: 'Online',
      isVirtual: true,
      meetingUrl: 'https://example.com/meeting',
    ),
  ));

  // ---- RSVPs (these also add calendar entries automatically) ---------------
  final mixer = (await db.getEvent(mixerId))!;
  await db.rsvp(mixer, alex, RsvpStatus.going);
  await db.rsvp(mixer, jordan, RsvpStatus.interested);

  // ---- A personal calendar entry --------------------------------------------
  await db.addPersonalCalendarEntry(
    jordan.id,
    CalendarEntry(
      id: '',
      title: 'Bio lab report due',
      startTime: daysFromNow(5, 23),
      endTime: daysFromNow(5, 23),
      type: CalendarEntryType.personal,
      reminderMinutesBefore: 120,
      color: '#E24A4A',
    ),
  );
}
