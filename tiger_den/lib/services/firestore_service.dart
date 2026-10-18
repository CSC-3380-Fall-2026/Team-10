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
    return _users.doc(user.id).set({
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  /// Live-updating user profile (the UI refreshes automatically on changes).
  Stream<AppUser?> streamUser(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  /// Updates only the fields you pass in, e.g.
  ///   updateUser(uid, {'bio': 'New bio', 'major': 'CS'});
  Future<void> updateUser(String uid, Map<String, dynamic> changes) {
    return _users.doc(uid).update({
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
    final orgRef = _orgs.doc(); // Firestore picks a random ID
    final batch = _db.batch();

    batch.set(orgRef, {
      ...org.toMap(),
      'ownerId': owner.id,
      'adminIds': [owner.id],
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_orgMembers(orgRef.id).doc(owner.id), {
      ...OrgMember(
        userId: owner.id,
        displayName: owner.displayName,
        role: OrgRole.owner,
      ).toMap(),
      'joinedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_userMemberships(owner.id).doc(orgRef.id), {
      ...Membership(orgId: orgRef.id, orgName: org.name, role: OrgRole.owner)
          .toMap(),
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return orgRef.id;
  }

  Future<Organization?> getOrganization(String orgId) async {
    final doc = await _orgs.doc(orgId).get();
    return doc.exists ? Organization.fromDoc(doc) : null;
  }

  Stream<Organization?> streamOrganization(String orgId) => _orgs
      .doc(orgId)
      .snapshots()
      .map((doc) => doc.exists ? Organization.fromDoc(doc) : null);

  /// All public clubs, alphabetical. For a "Browse Clubs" screen.
  Stream<List<Organization>> streamPublicOrganizations() => _orgs
      .where('isPublic', isEqualTo: true)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(Organization.fromDoc).toList();
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  Future<void> updateOrganization(String orgId, Map<String, dynamic> changes) {
    return _orgs.doc(orgId).update({
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adds [user] to a club. Writes to both the club's member list
  /// and the user's own "My Clubs" list, and bumps memberCount.
  Future<void> joinOrganization(Organization org, AppUser user) async {
    final memberRef = _orgMembers(org.id).doc(user.id);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(memberRef);
      if (existing.exists) return; // already a member, nothing to do

      final status =
          org.requiresApproval ? MemberStatus.pending : MemberStatus.active;

      tx.set(memberRef, {
        ...OrgMember(
          userId: user.id,
          displayName: user.displayName,
          status: status,
        ).toMap(),
        'joinedAt': FieldValue.serverTimestamp(),
      });
      tx.set(_userMemberships(user.id).doc(org.id), {
        ...Membership(orgId: org.id, orgName: org.name, status: status)
            .toMap(),
        'joinedAt': FieldValue.serverTimestamp(),
      });
      if (status == MemberStatus.active) {
        tx.update(_orgs.doc(org.id), {'memberCount': FieldValue.increment(1)});
      }
    });
  }

  Future<void> leaveOrganization(String orgId, String uid) async {
    final memberRef = _orgMembers(orgId).doc(uid);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(memberRef);
      if (!existing.exists) return;

      final wasActive = existing.data()?['status'] != MemberStatus.pending.name;

      tx.delete(memberRef);
      tx.delete(_userMemberships(uid).doc(orgId));
      if (wasActive) {
        tx.update(_orgs.doc(orgId), {'memberCount': FieldValue.increment(-1)});
      }
    });
  }

  /// Approves a pending join request (for clubs with requiresApproval).
  Future<void> approveMember(String orgId, String uid) async {
    final memberRef = _orgMembers(orgId).doc(uid);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(memberRef);
      if (!existing.exists) return;
      if (existing.data()?['status'] != MemberStatus.pending.name) return;

      tx.update(memberRef, {'status': MemberStatus.active.name});
      tx.update(_userMemberships(uid).doc(orgId),
          {'status': MemberStatus.active.name});
      tx.update(_orgs.doc(orgId), {'memberCount': FieldValue.increment(1)});
    });
  }

  /// Changes a member's role, e.g. promoting someone to admin.
  /// Keeps the club's adminIds list in sync so it can be used for
  /// permission checks ("can this user edit this club?").
  Future<void> setMemberRole(String orgId, String uid, OrgRole role) async {
    final batch = _db.batch();
    batch.update(_orgMembers(orgId).doc(uid), {'role': role.name});
    batch.update(_userMemberships(uid).doc(orgId), {'role': role.name});
    batch.update(_orgs.doc(orgId), {
      'adminIds': role == OrgRole.member
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Everyone in a club, for a members list screen.
  Stream<List<OrgMember>> streamOrgMembers(String orgId) => _orgMembers(orgId)
      .snapshots()
      .map((snap) => snap.docs.map(OrgMember.fromDoc).toList());

  /// The clubs a user belongs to, for a "My Clubs" screen.
  Stream<List<Membership>> streamMyMemberships(String uid) =>
      _userMemberships(uid)
          .snapshots()
          .map((snap) => snap.docs.map(Membership.fromDoc).toList());

  // ===========================================================================
  // EVENTS
  // ===========================================================================

  /// Creates an event and returns its new ID.
  Future<String> createEvent(Event event) async {
    final ref = await _events.add({
      ...event.toMap(),
      'attendeeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<Event?> getEvent(String eventId) async {
    final doc = await _events.doc(eventId).get();
    return doc.exists ? Event.fromDoc(doc) : null;
  }

  Stream<Event?> streamEvent(String eventId) => _events
      .doc(eventId)
      .snapshots()
      .map((doc) => doc.exists ? Event.fromDoc(doc) : null);

  /// Public, not-cancelled events that haven't started yet, soonest first.
  /// For the main feed / home screen.
  Stream<List<Event>> streamUpcomingEvents() => _events
      .where('startTime', isGreaterThanOrEqualTo: Timestamp.now())
      .orderBy('startTime')
      .snapshots()
      .map((snap) => snap.docs
          .map(Event.fromDoc)
          .where((e) =>
              e.visibility == EventVisibility.public &&
              e.status != EventStatus.cancelled)
          .toList());

  /// All events belonging to one club, soonest first.
  Stream<List<Event>> streamOrgEvents(String orgId) => _events
      .where('organizationId', isEqualTo: orgId)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(Event.fromDoc).toList();
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
        return list;
      });

  /// Events a specific user created.
  Stream<List<Event>> streamEventsCreatedBy(String uid) => _events
      .where('createdBy', isEqualTo: uid)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(Event.fromDoc).toList();
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
        return list;
      });

  /// Updates only the fields you pass in. Dates must be Timestamps, e.g.
  ///   updateEvent(id, {'startTime': Timestamp.fromDate(newStart)});
  Future<void> updateEvent(String eventId, Map<String, dynamic> changes) {
    return _events.doc(eventId).update({
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks an event cancelled. (Keeps it in the database so attendees
  /// can still see "Cancelled" instead of it just vanishing.)
  Future<void> cancelEvent(String eventId) =>
      updateEvent(eventId, {'status': EventStatus.cancelled.name});

  /// Permanently deletes an event. Note: Firestore does NOT delete
  /// subcollections automatically, so this removes attendees first.
  Future<void> deleteEvent(String eventId) async {
    final attendees = await _eventAttendees(eventId).get();
    final batch = _db.batch();
    for (final doc in attendees.docs) {
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
    final attendeeRef = _eventAttendees(event.id).doc(user.id);
    final calendarRef = _userCalendar(user.id).doc(event.id);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(attendeeRef);
      final wasGoing =
          existing.exists && existing.data()?['status'] == RsvpStatus.going.name;
      final isGoing = status == RsvpStatus.going;

      tx.set(attendeeRef, {
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
            {'attendeeCount': FieldValue.increment(1)});
      } else if (!isGoing && wasGoing) {
        tx.update(_events.doc(event.id),
            {'attendeeCount': FieldValue.increment(-1)});
      }
    });
  }

  /// Removes a user's RSVP entirely.
  Future<void> cancelRsvp(String eventId, String uid) async {
    final attendeeRef = _eventAttendees(eventId).doc(uid);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(attendeeRef);
      if (!existing.exists) return;

      final wasGoing = existing.data()?['status'] == RsvpStatus.going.name;

      tx.delete(attendeeRef);
      tx.delete(_userCalendar(uid).doc(eventId));
      if (wasGoing) {
        tx.update(
            _events.doc(eventId), {'attendeeCount': FieldValue.increment(-1)});
      }
    });
  }

  /// Everyone who RSVP'd to an event.
  Stream<List<Attendee>> streamAttendees(String eventId) =>
      _eventAttendees(eventId)
          .snapshots()
          .map((snap) => snap.docs.map(Attendee.fromDoc).toList());

  /// This user's RSVP on one event, or null if they haven't responded.
  Stream<Attendee?> streamMyRsvp(String eventId, String uid) =>
      _eventAttendees(eventId)
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? Attendee.fromDoc(doc) : null);

  // ===========================================================================
  // CALENDAR
  // ===========================================================================

  /// A user's whole calendar (RSVPs + personal entries), soonest first.
  Stream<List<CalendarEntry>> streamCalendar(String uid) => _userCalendar(uid)
      .orderBy('startTime')
      .snapshots()
      .map((snap) => snap.docs.map(CalendarEntry.fromDoc).toList());

  /// Adds something the user made themselves (not tied to an event).
  Future<String> addPersonalCalendarEntry(
      String uid, CalendarEntry entry) async {
    final ref = await _userCalendar(uid).add(entry.toMap());
    return ref.id;
  }

  Future<void> updateCalendarEntry(
          String uid, String entryId, Map<String, dynamic> changes) =>
      _userCalendar(uid).doc(entryId).update(changes);

  Future<void> deleteCalendarEntry(String uid, String entryId) =>
      _userCalendar(uid).doc(entryId).delete();
}
