import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'firestore_service.dart';

/// Handles sign up / log in / log out using Firebase Authentication.
///
/// Firebase Auth stores the email + password securely for you, so passwords
/// never go into Firestore. When someone signs up, we also create their
/// profile document at users/{uid} with the same ID.
class AuthService {
  AuthService({FirebaseAuth? auth, FirestoreService? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirestoreService();

  final FirebaseAuth _auth;
  final FirestoreService _db;

  /// The logged-in user's ID, or null if nobody is logged in.
  String? get currentUid => _auth.currentUser?.uid;

  /// Fires whenever someone logs in or out. Handy for deciding whether
  /// to show the login screen or the home screen.
  Stream<User?> get authChanges => _auth.authStateChanges();

  /// Creates a login account AND a profile document.
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
    String firstName = '',
    String lastName = '',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = AppUser(
      id: cred.user!.uid,
      email: email.trim(),
      username: username.trim(),
      displayName: displayName.trim(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    );
    await _db.createUserProfile(user);
    return user;
  }

  Future<void> logIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> logOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
}
