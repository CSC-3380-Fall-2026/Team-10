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

## Things to know

- **Copied fields.** `organizationName` and `orgName` are copies. If a club is
  renamed, those copies need updating too.
- **Linked writes.** Joining a club and RSVPing each write to several places at
  once, using batches/transactions, so the data never ends up half-saved.
  Always go through `FirestoreService` rather than writing to Firestore
  directly, so this stays consistent.
- **Sample users can't log in.** Accounts made by the seed script are profiles
  only. Real accounts come from `AuthService.signUp`.
