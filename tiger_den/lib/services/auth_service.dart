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

  /// Emails the user a link to reset their password.
  ///
  /// Firebase sends the email, the user picks a new password on Firebase's
  /// reset page, and Firebase updates the stored (hashed) password itself.
  /// Passwords never pass through our code or Firestore.
  ///
  /// If something goes wrong, this throws a [PasswordResetException] whose
  /// `message` is friendly enough to show the user directly:
  ///
  ///   try {
  ///     await AuthService().sendPasswordReset(email);
  ///     // show: "If an account exists for this email, a reset link was sent."
  ///   } on PasswordResetException catch (e) {
  ///     // show: e.message
  ///   }
  ///
  /// Note: for privacy, Firebase does NOT say whether an account exists for
  /// the email (so strangers can't check who has an account). An unknown
  /// email "succeeds" but no email is sent. That's why the success message
  /// above says "If an account exists...".
  Future<void> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw const PasswordResetException(
          'missing-email', 'Please enter your email address.');
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      throw const PasswordResetException(
          'invalid-email', 'That email address doesn\'t look right.');
    }

    try {
      await _auth.sendPasswordResetEmail(email: trimmed);
    } on FirebaseAuthException catch (e) {
      throw PasswordResetException(e.code, _friendlyResetMessage(e.code));
    } catch (_) {
      throw PasswordResetException('unknown', _friendlyResetMessage('unknown'));
    }
  }

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String _friendlyResetMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'missing-email':
        return 'Please enter your email address.';
      case 'user-not-found':
        return 'No account was found for that email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your connection and try again.';
      default:
        return 'We couldn\'t send the reset email. Please try again later.';
    }
  }
}

/// Thrown by [AuthService.sendPasswordReset] when the reset email can't be
/// sent. [message] is safe to show the user; [code] is for your own checks
/// (e.g. 'invalid-email', 'too-many-requests', 'network-request-failed').
class PasswordResetException implements Exception {
  const PasswordResetException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}
