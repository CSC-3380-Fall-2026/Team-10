import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

enum EventVisibility { public, membersOnly }

enum EventStatus { scheduled, cancelled, completed }

enum RsvpStatus { going, interested, notGoing }

/// Where an event happens. Saved as a nested map inside the event.
class EventLocation {
  final String name;
  final String? address;
  final GeoPoint? geo; // latitude/longitude, for maps later
  final bool isVirtual;
  final String? meetingUrl; // Zoom/Teams link if virtual

  EventLocation({
    required this.name,
    this.address,
    this.geo,
    this.isVirtual = false,
    this.meetingUrl,
  });

  factory EventLocation.fromMap(dynamic raw) {
    final m = dynamicMap(raw);
    return EventLocation(
      name: m['name'] ?? '',
      address: m['address'],
      geo: m['geo'] is GeoPoint ? m['geo'] : null,
      isVirtual: m['isVirtual'] ?? false,
      meetingUrl: m['meetingUrl'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'geo': geo,
        'isVirtual': isVirtual,
        'meetingUrl': meetingUrl,
      };
}

/// An event. Publicly visible, but owned by the user in [createdBy]
/// and (optionally) belonging to an organization.
/// Stored at: events/{id}
class Event {
  final String id;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final String? imageUrl;

  /// Null if a user is hosting this on their own, not through a club.
  final String? organizationId;
  final String? organizationName;

  final String createdBy;
  final List<String> hostIds;

  final DateTime startTime;
  final DateTime endTime;
  final bool allDay;
  final String timezone;

  final EventLocation location;

  /// Null means unlimited.
  final int? capacity;
  final int attendeeCount;

  final EventVisibility visibility;
  final EventStatus status;

  /// Optional, e.g. 'weekly'. Fine to ignore for the first version.
  final String? recurrence;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Event({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.description = '',
    this.category = '',
    this.tags = const [],
    this.imageUrl,
    this.organizationId,
    this.organizationName,
    this.hostIds = const [],
    this.allDay = false,
    this.timezone = 'America/Chicago',
    this.capacity,
    this.attendeeCount = 0,
    this.visibility = EventVisibility.public,
    this.status = EventStatus.scheduled,
    this.recurrence,
    this.createdAt,
    this.updatedAt,
  });

  factory Event.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Event(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? '',
      tags: stringList(d['tags']),
      imageUrl: d['imageUrl'],
      organizationId: d['organizationId'],
      organizationName: d['organizationName'],
      createdBy: d['createdBy'] ?? '',
      hostIds: stringList(d['hostIds']),
      startTime: dateFrom(d['startTime']) ?? DateTime.now(),
      endTime: dateFrom(d['endTime']) ?? DateTime.now(),
      allDay: d['allDay'] ?? false,
      timezone: d['timezone'] ?? 'America/Chicago',
      location: EventLocation.fromMap(d['location']),
      capacity: d['capacity'],
      attendeeCount: d['attendeeCount'] ?? 0,
      visibility: enumFrom(
          EventVisibility.values, d['visibility'], EventVisibility.public),
      status: enumFrom(EventStatus.values, d['status'], EventStatus.scheduled),
      recurrence: d['recurrence'],
      createdAt: dateFrom(d['createdAt']),
      updatedAt: dateFrom(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'category': category,
        'tags': tags,
        'imageUrl': imageUrl,
        'organizationId': organizationId,
        'organizationName': organizationName,
        'createdBy': createdBy,
        'hostIds': hostIds,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'allDay': allDay,
        'timezone': timezone,
        'location': location.toMap(),
        'capacity': capacity,
        'attendeeCount': attendeeCount,
        'visibility': visibility.name,
        'status': status.name,
        'recurrence': recurrence,
      };
}

/// One RSVP on an event.
/// Stored at: events/{eventId}/attendees/{userId}
class Attendee {
  final String userId;
  final String displayName;
  final RsvpStatus status;
  final DateTime? rsvpAt;

  Attendee({
    required this.userId,
    required this.displayName,
    this.status = RsvpStatus.going,
    this.rsvpAt,
  });

  factory Attendee.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Attendee(
      userId: doc.id,
      displayName: d['displayName'] ?? '',
      status: enumFrom(RsvpStatus.values, d['status'], RsvpStatus.going),
      rsvpAt: dateFrom(d['rsvpAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'status': status.name,
      };
}
