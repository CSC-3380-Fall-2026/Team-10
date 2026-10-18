import 'package:cloud_firestore/cloud_firestore.dart';

/// Small helpers shared by all the model classes.
/// Firestore gives data back as loosely-typed maps, so these
/// convert values safely into proper Dart types.

/// Firestore stores dates as `Timestamp`. This turns one into a Dart DateTime.
DateTime? dateFrom(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// Turns a stored string like "going" back into an enum value like RsvpStatus.going.
/// If the value is missing or unrecognized, returns [fallback] instead of crashing.
T enumFrom<T extends Enum>(List<T> values, dynamic name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Safely reads a list of strings (e.g. tags, adminIds).
List<String> stringList(dynamic value) => value is List
    ? value.map<String>((e) => e.toString()).toList()
    : <String>[];

/// Safely reads a map of strings (e.g. socialLinks).
Map<String, String> stringMap(dynamic value) => value is Map
    ? value.map<String, String>(
        (k, v) => MapEntry(k.toString(), v.toString()))
    : <String, String>{};

/// Safely reads a nested map (e.g. an event's location).
Map<String, dynamic> dynamicMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
