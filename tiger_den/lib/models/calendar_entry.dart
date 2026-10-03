import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// 'rsvp' = added automatically when the user RSVPs to an event.
/// 'personal' = something the user added to their own calendar.
enum CalendarEntryType { rsvp, personal }

/// One item on a user's personal calendar.
/// Stored at: users/{userId}/calendar/{id}
/// For RSVP entries, the document ID is the event's ID, so each event
/// can only appear once on someone's calendar.
class CalendarEntry {
  final String id;
  final String? eventId; // null for personal entries
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final bool allDay;
  final String? location;
  final CalendarEntryType type;
  final int? reminderMinutesBefore;
  final String? color; // e.g. '#4A90E2'

  CalendarEntry({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.eventId,
    this.allDay = false,
    this.location,
    this.type = CalendarEntryType.personal,
    this.reminderMinutesBefore,
    this.color,
  });

  factory CalendarEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CalendarEntry(
      id: doc.id,
      eventId: d['eventId'],
      title: d['title'] ?? '',
      startTime: dateFrom(d['startTime']) ?? DateTime.now(),
      endTime: dateFrom(d['endTime']) ?? DateTime.now(),
      allDay: d['allDay'] ?? false,
      location: d['location'],
      type: enumFrom(
          CalendarEntryType.values, d['type'], CalendarEntryType.personal),
      reminderMinutesBefore: d['reminderMinutesBefore'],
      color: d['color'],
    );
  }

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'title': title,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'allDay': allDay,
        'location': location,
        'type': type.name,
        'reminderMinutesBefore': reminderMinutesBefore,
        'color': color,
      };
}
