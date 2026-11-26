import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/calendar_entry.dart';
import '../models/event.dart';
import '../models/organization.dart';

/// Every read and write to Firestore goes through this class,
/// so the rest of the app never has to remember collection names.
///
/// Usage from any screen:
///   final db = FirestoreService();
///   final events = db.streamUpcomingEvents();
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ---------------------------------------------------------------------------
  // Collection shortcuts
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _orgs =>
      _db.collection('organizations');
  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  CollectionReference<Map<String, dynamic>> _orgMembers(String orgId) =>
      _orgs.doc(orgId).collection('members');
  CollectionReference<Map<String, dynamic>> _userMemberships(String uid) =>
      _users.doc(uid).collection('memberships');
  CollectionReference<Map<String, dynamic>> _userCalendar(String uid) =>
      _users.doc(uid).collection('calendar');
  CollectionReference<Map<String, dynamic>> _eventAttendees(String eventId) =>
      _events.doc(eventId).collection('attendees');

  // ===========================================================================
  // USERS
  // ===========================================================================

  /// Creates the profile document for a user who just signed up.
  Future<void> createUserProfile(AppUser user) {
    return _users.doc(user.id).set(<String, dynamic>{
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _users.doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  /// Live-updating user profile (the UI refreshes automatically on changes).
  Stream<AppUser?> streamUser(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  /// Updates only the fields you pass in, e.g.
  ///   updateUser(uid, {'bio': 'New bio', 'major': 'CS'});
  Future<void> updateUser(String uid, Map<String, dynamic> changes) {
    return _users.doc(uid).update(<Object, Object?>{
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================================
  // ORGANIZATIONS
  // ===========================================================================

  /// Creates a club and makes [owner] its first member (role: owner).
  /// Returns the new organization's ID.
  ///
  /// A "batch" makes all the writes happen together: either every one
  /// succeeds or none do, so the data never ends up half-saved.
  Future<String> createOrganization(Organization org, AppUser owner) async {
    final DocumentReference<Map<String, dynamic>> orgRef = _orgs.doc(); // Firestore picks a random ID
    final WriteBatch batch = _db.batch();

    batch.set(orgRef, <String, dynamic>{
      ...org.toMap(),
      'ownerId': owner.id,
      'adminIds': <String>[owner.id],
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_orgMembers(orgRef.id).doc(owner.id), <String, dynamic>{
      ...OrgMember(
        userId: owner.id,
        displayName: owner.displayName,
        role: OrgRole.owner,
      ).toMap(),
      'joinedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_userMemberships(owner.id).doc(orgRef.id), <String, dynamic>{
      ...Membership(orgId: orgRef.id, orgName: org.name, role: OrgRole.owner)
          .toMap(),
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return orgRef.id;
  }

  Future<Organization?> getOrganization(String orgId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _orgs.doc(orgId).get();
    return doc.exists ? Organization.fromDoc(doc) : null;
  }

  Stream<Organization?> streamOrganization(String orgId) => _orgs
      .doc(orgId)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists ? Organization.fromDoc(doc) : null);

  /// All public clubs, alphabetical. For a "Browse Clubs" screen.
  Stream<List<Organization>> streamPublicOrganizations() => _orgs
      .where('isPublic', isEqualTo: true)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) {
        final List<Organization> list = snap.docs.map(Organization.fromDoc).toList();
        list.sort(
            (Organization a, Organization b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  /// Updates only the fields you pass in, e.g.
  ///   updateOrganization(orgId, {'description': 'New description'});
  ///
  /// This always edits the club's existing document (same ID), so it never
  /// makes a copy. If the club doesn't exist, it throws instead of creating one.
  ///
  /// If the change includes a NEW 'name', the copies of the club's name
  /// stored elsewhere are updated too, so nothing shows the old name:
  ///   - events/{eventId}.organizationName      (the club's events)
  ///   - users/{uid}/memberships/{orgId}.orgName (members' "My Clubs" lists)
  /// When the name is unchanged, nothing extra is read or written.
  Future<void> updateOrganization(
      String orgId, Map<String, dynamic> changes) async {
    final DocumentReference<Map<String, dynamic>> orgRef = _orgs.doc(orgId);

    final newName = changes['name'];
    String? oldName;
    if (newName is String) {
      final DocumentSnapshot<Map<String, dynamic>> current = await orgRef.get();
      if (!current.exists) {
        throw StateError('Club $orgId does not exist.');
      }
      oldName = current.data()?['name'] as String?;
    }

    await orgRef.update(<Object, Object?>{
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (newName is String && newName != oldName) {
      await _renameClubCopies(orgId, newName);
    }
  }

  /// Rewrites every stored copy of a club's name after it's renamed.
  Future<void> _renameClubCopies(String orgId, String newName) async {
    final QuerySnapshot<Map<String, dynamic>> events =
        await _events.where('organizationId', isEqualTo: orgId).get();
    final QuerySnapshot<Map<String, dynamic>> members = await _orgMembers(orgId).get();

    final List<MapEntry<DocumentReference<Object?>, Map<String, dynamic>>> refsAndChanges = <MapEntry<DocumentReference, Map<String, dynamic>>>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in events.docs)
        MapEntry(doc.reference, <String, dynamic>{'organizationName': newName}),
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in members.docs)
        MapEntry(_userMemberships(doc.id).doc(orgId), <String, dynamic>{'orgName': newName}),
    ];

    // A Firestore batch holds at most 500 writes, so commit in chunks.
    const int chunkSize = 450;
    for (int i = 0; i < refsAndChanges.length; i += chunkSize) {
      final WriteBatch batch = _db.batch();
      for (final MapEntry<DocumentReference<Object?>, Map<String, dynamic>> entry in refsAndChanges.skip(i).take(chunkSize)) {
        // set+merge so a missing membership copy is fixed instead of failing.
        batch.set(entry.key, entry.value, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  /// Adds [user] to a club. Writes to both the club's member list
  /// and the user's own "My Clubs" list, and bumps memberCount.
  Future<void> joinOrganization(Organization org, AppUser user) async {
    final DocumentReference<Map<String, dynamic>> memberRef = _orgMembers(org.id).doc(user.id);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> existing = await tx.get(memberRef);
      if (existing.exists) return; // already a member, nothing to do

      final MemberStatus status =
          org.requiresApproval ? MemberStatus.pending : MemberStatus.active;

      tx.set(memberRef, <String, dynamic>{
        ...OrgMember(
          userId: user.id,
          displayName: user.displayName,
          status: status,
        ).toMap(),
        'joinedAt': FieldValue.serverTimestamp(),
      });
      tx.set(_userMemberships(user.id).doc(org.id), <String, dynamic>{
        ...Membership(orgId: org.id, orgName: org.name, status: status)
            .toMap(),
        'joinedAt': FieldValue.serverTimestamp(),
      });
      if (status == MemberStatus.active) {
        tx.update(_orgs.doc(org.id), <Object, Object?>{'memberCount': FieldValue.increment(1)});
      }
    });
  }

  Future<void> leaveOrganization(String orgId, String uid) async {
    final DocumentReference<Map<String, dynamic>> memberRef = _orgMembers(orgId).doc(uid);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> existing = await tx.get(memberRef);
      if (!existing.exists) return;

      final bool wasActive = existing.data()?['status'] != MemberStatus.pending.name;

      tx.delete(memberRef);
      tx.delete(_userMemberships(uid).doc(orgId));
      if (wasActive) {
        tx.update(_orgs.doc(orgId), <Object, Object?>{'memberCount': FieldValue.increment(-1)});
      }
    });
  }

  /// Approves a pending join request (for clubs with requiresApproval).
  Future<void> approveMember(String orgId, String uid) async {
    final DocumentReference<Map<String, dynamic>> memberRef = _orgMembers(orgId).doc(uid);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> existing = await tx.get(memberRef);
      if (!existing.exists) return;
      if (existing.data()?['status'] != MemberStatus.pending.name) return;

      tx.update(memberRef, <Object, Object?>{'status': MemberStatus.active.name});
      tx.update(_userMemberships(uid).doc(orgId),
          <Object, Object?>{'status': MemberStatus.active.name});
      tx.update(_orgs.doc(orgId), <Object, Object?>{'memberCount': FieldValue.increment(1)});
    });
  }

  /// Changes a member's role, e.g. promoting someone to admin.
  /// Keeps the club's adminIds list in sync so it can be used for
  /// permission checks ("can this user edit this club?").
  Future<void> setMemberRole(String orgId, String uid, OrgRole role) async {
    final WriteBatch batch = _db.batch();
    batch.update(_orgMembers(orgId).doc(uid), <String, String>{'role': role.name});
    batch.update(_userMemberships(uid).doc(orgId), <String, String>{'role': role.name});
    batch.update(_orgs.doc(orgId), <String, FieldValue>{
      'adminIds': role == OrgRole.member
          ? FieldValue.arrayRemove(<dynamic>[uid])
          : FieldValue.arrayUnion(<dynamic>[uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Everyone in a club, for a members list screen.
  Stream<List<OrgMember>> streamOrgMembers(String orgId) => _orgMembers(orgId)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs.map(OrgMember.fromDoc).toList());

  /// The clubs a user belongs to, for a "My Clubs" screen.
  Stream<List<Membership>> streamMyMemberships(String uid) =>
      _userMemberships(uid)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs.map(Membership.fromDoc).toList());

  // ===========================================================================
  // EVENTS
  // ===========================================================================

  /// Creates an event and returns its new ID.
  Future<String> createEvent(Event event) async {
    final DocumentReference<Map<String, dynamic>> ref = await _events.add(<String, dynamic>{
      ...event.toMap(),
      'attendeeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<Event?> getEvent(String eventId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _events.doc(eventId).get();
    return doc.exists ? Event.fromDoc(doc) : null;
  }

  Stream<Event?> streamEvent(String eventId) => _events
      .doc(eventId)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists ? Event.fromDoc(doc) : null);

  /// Public, not-cancelled events that haven't started yet, soonest first.
  /// For the main feed / home screen.
  Stream<List<Event>> streamUpcomingEvents() => _events
      .where('startTime', isGreaterThanOrEqualTo: Timestamp.now())
      .orderBy('startTime')
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
          .map(Event.fromDoc)
          .where((Event e) =>
              e.visibility == EventVisibility.public &&
              e.status != EventStatus.cancelled)
          .toList());

  /// All events belonging to one club, soonest first.
  Stream<List<Event>> streamOrgEvents(String orgId) => _events
      .where('organizationId', isEqualTo: orgId)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) {
        final List<Event> list = snap.docs.map(Event.fromDoc).toList();
        list.sort((Event a, Event b) => a.startTime.compareTo(b.startTime));
        return list;
      });

  /// Events a specific user created.
  Stream<List<Event>> streamEventsCreatedBy(String uid) => _events
      .where('createdBy', isEqualTo: uid)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) {
        final List<Event> list = snap.docs.map(Event.fromDoc).toList();
        list.sort((Event a, Event b) => a.startTime.compareTo(b.startTime));
        return list;
      });

  /// Updates only the fields you pass in. Dates must be Timestamps, e.g.
  ///   updateEvent(id, {'startTime': Timestamp.fromDate(newStart)});
  ///
  /// This always edits the event's existing document (same ID), so it never
  /// makes a copy. If the event doesn't exist, it throws instead.
  ///
  /// RSVPs copy the event's title, times and location into each attendee's
  /// calendar (users/{uid}/calendar/{eventId}). If [changes] touches any of
  /// those, the copies are updated too, so attendees never see old info.
  /// Other changes (description, tags, capacity...) cost no extra writes.
  Future<void> updateEvent(
      String eventId, Map<String, dynamic> changes) async {
    await _events.doc(eventId).update(<Object, Object?>{
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final Map<String, dynamic> calendarChanges = _calendarCopyFields(changes);
    if (calendarChanges.isNotEmpty) {
      await _updateAttendeeCalendars(eventId, calendarChanges);
    }
  }

  /// Picks out the event fields that are copied into attendees' calendars,
  /// renamed to how CalendarEntry stores them.
  static Map<String, dynamic> _calendarCopyFields(
      Map<String, dynamic> eventChanges) {
    final Map<String, dynamic> result = <String, dynamic>{};
    for (final String field in const <String>['title', 'startTime', 'endTime', 'allDay']) {
      if (eventChanges.containsKey(field)) result[field] = eventChanges[field];
    }
    final location = eventChanges['location'];
    if (location is Map) {
      result['location'] = location['name']; // calendar stores just the name
    }
    return result;
  }

  /// Updates the calendar copy of an event for everyone who RSVP'd
  /// "going" or "interested" (people who said "not going" have no copy).
  Future<void> _updateAttendeeCalendars(
      String eventId, Map<String, dynamic> calendarChanges) async {
    final QuerySnapshot<Map<String, dynamic>> attendees = await _eventAttendees(eventId).get();
    final List<String> uids = attendees.docs
        .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data()['status'] != RsvpStatus.notGoing.name)
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
        .toList();

    // A Firestore batch holds at most 500 writes, so commit in chunks.
    const int chunkSize = 450;
    for (int i = 0; i < uids.length; i += chunkSize) {
      final WriteBatch batch = _db.batch();
      for (final String uid in uids.skip(i).take(chunkSize)) {
        batch.set(_userCalendar(uid).doc(eventId), calendarChanges,
            SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  /// Marks an event cancelled. (Keeps it in the database so attendees
  /// can still see "Cancelled" instead of it just vanishing.)
  Future<void> cancelEvent(String eventId) =>
      updateEvent(eventId, <String, dynamic>{'status': EventStatus.cancelled.name});

  /// Permanently deletes an event. Note: Firestore does NOT delete
  /// subcollections automatically, so this removes attendees first.
  Future<void> deleteEvent(String eventId) async {
    final QuerySnapshot<Map<String, dynamic>> attendees = await _eventAttendees(eventId).get();
    final WriteBatch batch = _db.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in attendees.docs) {
      batch.delete(doc.reference);
      batch.delete(_userCalendar(doc.id).doc(eventId));
    }
    batch.delete(_events.doc(eventId));
    await batch.commit();
  }

  // ===========================================================================
  // RSVPs
  // ===========================================================================

  /// Sets a user's RSVP on an event (going / interested / notGoing).
  /// Also adds the event to the user's calendar, and keeps
  /// attendeeCount accurate (it counts only people who are "going").
  Future<void> rsvp(Event event, AppUser user, RsvpStatus status) async {
    final DocumentReference<Map<String, dynamic>> attendeeRef = _eventAttendees(event.id).doc(user.id);
    final DocumentReference<Map<String, dynamic>> calendarRef = _userCalendar(user.id).doc(event.id);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> existing = await tx.get(attendeeRef);
      final bool wasGoing =
          existing.exists && existing.data()?['status'] == RsvpStatus.going.name;
      final bool isGoing = status == RsvpStatus.going;

      tx.set(attendeeRef, <String, dynamic>{
        ...Attendee(
          userId: user.id,
          displayName: user.displayName,
          status: status,
        ).toMap(),
        'rsvpAt': FieldValue.serverTimestamp(),
      });

      if (status == RsvpStatus.notGoing) {
        tx.delete(calendarRef);
      } else {
        tx.set(
          calendarRef,
          CalendarEntry(
            id: event.id,
            eventId: event.id,
            title: event.title,
            startTime: event.startTime,
            endTime: event.endTime,
            allDay: event.allDay,
            location: event.location.name,
            type: CalendarEntryType.rsvp,
          ).toMap(),
        );
      }

      if (isGoing && !wasGoing) {
        tx.update(_events.doc(event.id),
            <Object, Object?>{'attendeeCount': FieldValue.increment(1)});
      } else if (!isGoing && wasGoing) {
        tx.update(_events.doc(event.id),
            <Object, Object?>{'attendeeCount': FieldValue.increment(-1)});
      }
    });
  }

  /// Removes a user's RSVP entirely.
  Future<void> cancelRsvp(String eventId, String uid) async {
    final DocumentReference<Map<String, dynamic>> attendeeRef = _eventAttendees(eventId).doc(uid);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> existing = await tx.get(attendeeRef);
      if (!existing.exists) return;

      final bool wasGoing = existing.data()?['status'] == RsvpStatus.going.name;

      tx.delete(attendeeRef);
      tx.delete(_userCalendar(uid).doc(eventId));
      if (wasGoing) {
        tx.update(
            _events.doc(eventId), <Object, Object?>{'attendeeCount': FieldValue.increment(-1)});
      }
    });
  }

  /// Everyone who RSVP'd to an event.
  Stream<List<Attendee>> streamAttendees(String eventId) =>
      _eventAttendees(eventId)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs.map(Attendee.fromDoc).toList());

  /// This user's RSVP on one event, or null if they haven't responded.
  Stream<Attendee?> streamMyRsvp(String eventId, String uid) =>
      _eventAttendees(eventId)
          .doc(uid)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists ? Attendee.fromDoc(doc) : null);

  // ===========================================================================
  // CALENDAR
  // ===========================================================================

  /// A user's whole calendar (RSVPs + personal entries), soonest first.
  Stream<List<CalendarEntry>> streamCalendar(String uid) => _userCalendar(uid)
      .orderBy('startTime')
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs.map(CalendarEntry.fromDoc).toList());

  /// Adds something the user made themselves (not tied to an event).
  Future<String> addPersonalCalendarEntry(
      String uid, CalendarEntry entry) async {
    final DocumentReference<Map<String, dynamic>> ref = await _userCalendar(uid).add(entry.toMap());
    return ref.id;
  }

  Future<void> updateCalendarEntry(
          String uid, String entryId, Map<String, dynamic> changes) =>
      _userCalendar(uid).doc(entryId).update(changes);

  Future<void> deleteCalendarEntry(String uid, String entryId) =>
      _userCalendar(uid).doc(entryId).delete();
}
