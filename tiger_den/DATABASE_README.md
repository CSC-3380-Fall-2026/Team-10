# Database Setup (Firestore)

Everything for the database lives in these folders. Drop them into the
project's `lib/` folder, keeping the same folder names.

```
lib/
├── models/
│   ├── model_utils.dart      helper functions the models share
│   ├── app_user.dart         AppUser
│   ├── organization.dart     Organization, OrgMember, Membership
│   ├── event.dart            Event, EventLocation, Attendee
│   └── calendar_entry.dart   CalendarEntry
├── services/
│   ├── firestore_service.dart   every database read/write
│   └── auth_service.dart        sign up / log in / log out
└── dev/
    └── seed_data.dart        fills the database with sample data (run once)
```

## Steps once you have project access

1. **Create the database** (skip if it already exists): Firebase Console →
   Build → Firestore Database → Create database → pick `us-central` →
   **Start in test mode**.
2. **Turn on login**: Firebase Console → Build → Authentication → Get started
   → Sign-in method → enable **Email/Password**.
3. **Add the packages**. In the VS Code terminal, from the project folder:
   ```
   flutter pub add cloud_firestore firebase_auth
   ```
   (`firebase_core` should already be there from the project setup.)
4. **Copy the folders** above into `lib/`.
5. **Load sample data once.** In `main.dart`, add the import at the top:
   ```dart
   import 'dev/seed_data.dart';
   ```
   and right after the `await Firebase.initializeApp(...)` line, add:
   ```dart
   await seedSampleData();
   ```
   Run the app one time, open Firestore in the Console to see the data, then
   **delete that `seedSampleData()` line** so it doesn't duplicate data on
   every launch.

> Heads-up: test mode lets anyone read/write and **expires after 30 days**.
> Before then, the group will need real security rules.

## Using it from a screen

```dart
final db = FirestoreService();
final auth = AuthService();

// Show upcoming events, updating live:
StreamBuilder<List<Event>>(
  stream: db.streamUpcomingEvents(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    final events = snapshot.data!;
    return ListView(
      children: [for (final e in events) ListTile(title: Text(e.title))],
    );
  },
);

// Sign up:
await auth.signUp(
  email: 'me@school.edu',
  password: 'secret123',
  username: 'me',
  displayName: 'My Name',
);
```

## Database structure

```
users/{userId}                      (userId = Firebase Auth UID)
  ├─ memberships/{orgId}            clubs this user is in
  └─ calendar/{entryId}             RSVPs + personal entries
organizations/{orgId}
  └─ members/{userId}               who's in the club + role
events/{eventId}
  └─ attendees/{userId}             RSVPs
```

Events and organizations are top-level so anyone can browse them. Ownership
is tracked with `createdBy` (events) and `ownerId` / `adminIds` (clubs).

### users/{userId}
| Field | Type | Notes |
|---|---|---|
| email | string | |
| username | string | |
| displayName | string | name shown in the app |
| firstName, lastName | string | |
| profilePhotoUrl | string? | |
| bio | string | |
| phone | string? | |
| major | string? | |
| gradYear | number? | |
| interests | array of strings | for recommendations later |
| createdAt, updatedAt | timestamp | set automatically |

Passwords are **not** stored here. Firebase Authentication handles them.

### users/{userId}/memberships/{orgId}
| Field | Type | Notes |
|---|---|---|
| orgName | string | copy of the club's name |
| role | string | `owner` / `admin` / `member` |
| joinedAt | timestamp | |

### users/{userId}/calendar/{entryId}
| Field | Type | Notes |
|---|---|---|
| eventId | string? | null for personal entries |
| title | string | |
| startTime, endTime | timestamp | |
| allDay | bool | |
| location | string? | |
| type | string | `rsvp` / `personal` |
| reminderMinutesBefore | number? | |
| color | string? | e.g. `#4A90E2` |

For RSVP entries, the entry ID equals the event ID.

### organizations/{orgId}
| Field | Type | Notes |
|---|---|---|
| name, description, category | string | |
| tags | array of strings | |
| logoUrl, bannerUrl | string? | |
| contactEmail | string? | |
| socialLinks | map | `{instagram: url, discord: url}` |
| meetingInfo | map | `{day, time, location}` |
| ownerId | string | user who owns the club |
| adminIds | array of strings | users who can edit it |
| memberCount | number | kept up to date automatically |
| isPublic | bool | |
| requiresApproval | bool | if true, joiners start as `pending` |
| createdAt, updatedAt | timestamp | |

### organizations/{orgId}/members/{userId}
| Field | Type | Notes |
|---|---|---|
| displayName | string | |
| role | string | `owner` / `admin` / `member` |
| status | string | `active` / `pending` |
| joinedAt | timestamp | |

### events/{eventId}
| Field | Type | Notes |
|---|---|---|
| title, description, category | string | |
| tags | array of strings | |
| imageUrl | string? | |
| organizationId | string? | null if hosted by a user, not a club |
| organizationName | string? | copy of the club's name |
| createdBy | string | owner user ID |
| hostIds | array of strings | |
| startTime, endTime | timestamp | |
| allDay | bool | |
| timezone | string | e.g. `America/Chicago` |
| location | map | `{name, address, geo, isVirtual, meetingUrl}` |
| capacity | number? | null = unlimited |
| attendeeCount | number | counts "going" RSVPs, kept up to date |
| visibility | string | `public` / `membersOnly` |
| status | string | `scheduled` / `cancelled` / `completed` |
| recurrence | string? | optional, e.g. `weekly` |
| createdAt, updatedAt | timestamp | |

### events/{eventId}/attendees/{userId}
| Field | Type | Notes |
|---|---|---|
| displayName | string | |
| status | string | `going` / `interested` / `notGoing` |
| rsvpAt | timestamp | |

## Test data (from `lib/dev/seed_data.dart`)

Everything is labeled so it's obvious what it's for when testing.

| Test user | Document ID | Permissions it tests |
|---|---|---|
| User A | `test_user_a` | Owner of User A's Club |
| User B | `test_user_b` | Owner of User B's Club; **admin** in User A's Club |
| User C | `test_user_c` | Regular member of both clubs (approved into User B's Club) |
| User D | `test_user_d` | **Pending** member of User B's Club |
| User E | `test_user_e` | In no clubs; hosts their own event |

| Club | Joining | Members | memberCount |
|---|---|---|---|
| User A's Club | Open | A (owner), B (admin), C (member) | 3 |
| User B's Club | Requires approval | B (owner), C (member), D (pending) | 2 (pending not counted) |

| Event | Type | RSVPs | attendeeCount |
|---|---|---|---|
| User A's Event | Public, User A's Club | A, B, C going; E interested | 3 |
| User B's Members-Only Event | Members only, User B's Club | B, C going | 2 |
| User A's Cancelled Event | Cancelled | none | 0 |
| User E's Event (No Club, Virtual) | No club, online | E going; A not going | 1 |
| User C's Past Event | Completed, last week | C going | 1 |

Calendars: A has 1 entry, B has 2, C has 4 (including a personal reminder),
D has 0, E has 2.

Test users are profile documents only, not login accounts.

## Things to know

- **Copied fields.** `organizationName` and `orgName` are copies. If a club is
  renamed, those copies need updating too.
- **Linked writes.** Joining a club and RSVPing each write to several places at
  once, using batches/transactions, so the data never ends up half-saved.
  Always go through `FirestoreService` rather than writing to Firestore
  directly, so this stays consistent.
- **Sample users can't log in.** Accounts made by the seed script are profiles
  only. Real accounts come from `AuthService.signUp`.

## Login sessions

Login is handled by **Firebase Authentication**. When a user logs in, Firebase
creates a session for that device and saves it, so the user stays logged in
after closing and reopening the app, until they log out. Each device has its
own session, so different users on different phones are fully separate.

`lib/services/session_service.dart` keeps track of the active session:

```dart
final session = SessionService.instance;

session.isLoggedIn;            // true / false
session.currentUid;            // logged-in user's ID (same as users/{uid}), or null
session.session?.sessionId;    // unique ID for this session
await session.logIn(email, password);
await session.logOut();

// Rebuild a widget whenever someone logs in or out:
ListenableBuilder(
  listenable: SessionService.instance,
  builder: (context, _) => Text(SessionService.instance.currentUid ?? 'Logged out'),
);
```

`session.isReady` is false for a moment at startup while Firebase checks for a
saved login. Show a loading spinner until it's true.

### Testing sessions without the login screen

Two dummy login accounts exist in Firebase Authentication (listed in
`lib/dev/test_accounts.dart`):

| Account | Email | Password |
|---|---|---|
| Test User 1 | testuser1@tigerden.dev | TigerDenTest1! |
| Test User 2 | testuser2@tigerden.dev | TigerDenTest2! |

These are test-only. The repository is public, so never reuse them.

Run the session test page instead of the normal app (from `tiger_den`):

```
flutter run -t lib/dev/session_test_main.dart -d emulator-5554
```

It shows who's logged in, their user ID, and the session ID, with buttons to
log in as either test user or log out. `main.dart` is not affected.



## Loading the logged-in user's profile

`lib/services/current_user_service.dart` loads the logged-in user's profile
(`users/{uid}`) into the session. When someone logs in, it takes their user ID
from `SessionService` and loads their profile. When they log out, it clears it.
The profile stays live, so changes in the database show up automatically.

```dart
final me = CurrentUserService.instance;

me.user?.displayName;   // logged-in user's profile (AppUser), or null
me.isLoading;           // true while the profile is loading
me.isMissingProfile;    // logged in, but no users/{uid} document exists

// Rebuild a widget when the profile loads or changes:
ListenableBuilder(
  listenable: CurrentUserService.instance,
  builder: (context, _) =>
      Text(CurrentUserService.instance.user?.displayName ?? 'Guest'),
);
```

Only one database listener is open at a time (for the logged-in user), so
using it from many screens doesn't cause extra reads.

The 2 test login accounts have matching profiles in `users/` (display names
"Test User 1" and "Test User 2"). On the session test page, logging in shows
both the session and the loaded profile. If an account has no profile yet,
the page offers a "Create test profile" button.


## Password reset

`AuthService.sendPasswordReset(email)` emails the user a link to reset their
password. Firebase sends the email, the user picks a new password on Firebase's
reset page, and Firebase updates the stored (hashed) password itself.
Passwords never pass through our code or Firestore.

If it fails, it throws a `PasswordResetException` whose `message` is safe to
show the user (e.g. "Too many attempts. Please wait a few minutes and try
again."):

```dart
try {
  await AuthService().sendPasswordReset(email);
  // "If an account exists for this email, a reset link was sent."
} on PasswordResetException catch (e) {
  // show e.message
}
```

For privacy, Firebase doesn't reveal whether an account exists for an email,
so an unknown email still "succeeds" (no email is sent). Word the success
message as "If an account exists...".

The login page's "Forgot Password?" dialog already uses this.

**Testing:** `flutter run -t lib/dev/password_reset_test_main.dart -d emulator-5554`
sends a reset email and then checks that the new password logs in. Use an
account with a real inbox (the `@tigerden.dev` test accounts can't receive
email). The email comes from `noreply@...firebaseapp.com`, so check spam.

**Email template:** Firebase currently blocks editing the email templates for
this project ("Email template updates are currently unavailable"), so the
default reset email is used.