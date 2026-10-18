import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// One user of the app.
/// Stored at: users/{id}
/// The document ID is the user's Firebase Auth UID, so a user's login
/// and their profile always share the same ID.
class AppUser {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String firstName;
  final String lastName;
  final String? profilePhotoUrl;
  final String bio;
  final String? phone;
  final String? major;
  final int? gradYear;
  final List<String> interests;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.firstName = '',
    this.lastName = '',
    this.profilePhotoUrl,
    this.bio = '',
    this.phone,
    this.major,
    this.gradYear,
    this.interests = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Builds an AppUser from a document read out of Firestore.
  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppUser(
      id: doc.id,
      email: d['email'] ?? '',
      username: d['username'] ?? '',
      displayName: d['displayName'] ?? '',
      firstName: d['firstName'] ?? '',
      lastName: d['lastName'] ?? '',
      profilePhotoUrl: d['profilePhotoUrl'],
      bio: d['bio'] ?? '',
      phone: d['phone'],
      major: d['major'],
      gradYear: d['gradYear'],
      interests: stringList(d['interests']),
      createdAt: dateFrom(d['createdAt']),
      updatedAt: dateFrom(d['updatedAt']),
    );
  }

  /// Converts this user into a map Firestore can save.
  /// (The id is not included because it's the document's name, not a field.)
  Map<String, dynamic> toMap() => {
        'email': email,
        'username': username,
        'displayName': displayName,
        'firstName': firstName,
        'lastName': lastName,
        'profilePhotoUrl': profilePhotoUrl,
        'bio': bio,
        'phone': phone,
        'major': major,
        'gradYear': gradYear,
        'interests': interests,
      };
}
