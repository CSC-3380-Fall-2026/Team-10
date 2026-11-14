import 'package:flutter/material.dart';

/// Shared choices for the club creation and club editing pages.
/// Add or rename categories here and both pages update.
class ClubOptions {
  ClubOptions._();

  /// The categories a club can pick from.
  static const List<String> categories = [
    'Academic',
    'Professional',
    'Cultural',
    'Faith & Spiritual',
    'Greek Life',
    'Hobby & Interest',
    'Arts & Performance',
    'Sports & Recreation',
    'Service & Volunteer',
    'Social',
    'Student Government',
    'Other',
  ];

  /// The days a club can say it meets on.
  static const List<String> meetingDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
    'Varies',
  ];

  /// Returns [options], plus [current] at the end if it isn't already in the
  /// list. This keeps an older saved value (e.g. a category typed in before
  /// the dropdowns existed) selectable instead of silently losing it.
  static List<String> withCurrent(List<String> options, String? current) {
    if (current == null || current.isEmpty || options.contains(current)) {
      return options;
    }
    return [...options, current];
  }

  /// Like [withCurrent], for several values (e.g. a club's existing tags).
  static List<String> withAll(List<String> options, Iterable<String> current) {
    return [...options, ...current.where((v) => !options.contains(v))];
  }

  /// Formats a meeting time the same way every time it's saved, e.g. "6:00 PM".
  static String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Reads a saved meeting time like "6:00 PM" or "18:00".
  /// Returns null if the text isn't a time.
  static TimeOfDay? parseTime(String? text) {
    if (text == null) return null;
    final match = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])?\s*$')
        .firstMatch(text);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)?.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
