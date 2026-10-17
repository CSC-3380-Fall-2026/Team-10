import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// One active login session on this device.
class Session {
  /// The logged-in user's Firebase Auth ID. This is also the ID of their
  /// profile document at users/{uid}.
  final String uid;
  final String? email;

  /// A random ID unique to this session. A new one is made each time a user
  /// logs in (or the app reopens with a saved login), so two sessions are
  /// never confused, even for the same user.
  final String sessionId;

  /// When this session started on this device.
  final DateTime startedAt;

  const Session({
    required this.uid,
    required this.sessionId,
    required this.startedAt,
    this.email,
  });
}

/// Keeps track of who is logged in on this device right now.
///
/// Firebase Authentication does the real work: when someone logs in, Firebase
/// creates a session for this device and saves it, so the user stays logged
/// in even after closing and reopening the app. This class listens to Firebase
/// and keeps an up-to-date [Session] that any screen can read.
///
/// Usage from anywhere in the app:
///   final session = SessionService.instance;
///   session.isLoggedIn;      // true / false
///   session.currentUid;      // the logged-in user's ID, or null
///   await session.logIn(email, password);
///   await session.logOut();
///
/// To rebuild a widget when someone logs in or out:
///   ListenableBuilder(
///     listenable: SessionService.instance,
///     builder: (context, _) => Text(SessionService.instance.currentUid ?? 'Logged out'),
///   );
///
/// Note: only use this AFTER `Firebase.initializeApp(...)` has run in main().
class SessionService extends ChangeNotifier {
  SessionService._() : _auth = FirebaseAuth.instance {
    _subscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// The one shared SessionService for the whole app.
  static final SessionService instance = SessionService._();

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;

  Session? _session;
  bool _isReady = false;

  /// The current session, or null if nobody is logged in.
  Session? get session => _session;

  bool get isLoggedIn => _session != null;

  /// The logged-in user's ID, or null if nobody is logged in.
  String? get currentUid => _session?.uid;

  /// False for a brief moment at app start while Firebase checks for a saved
  /// login. Screens can show a loading spinner until this is true, instead of
  /// flashing the login screen for a user who is already logged in.
  bool get isReady => _isReady;

  /// Logs in with email and password. Firebase starts the session, and
  /// [session] updates automatically a moment later.
  /// Throws a [FirebaseAuthException] if the email/password is wrong.
  Future<void> logIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Ends the session on this device.
  Future<void> logOut() => _auth.signOut();

  void _onAuthStateChanged(User? user) {
    if (user == null) {
      _session = null;
    } else if (_session?.uid != user.uid) {
      // A different user (or the first user) just logged in: new session.
      _session = Session(
        uid: user.uid,
        email: user.email,
        sessionId: _newSessionId(),
        startedAt: DateTime.now(),
      );
    }
    _isReady = true;
    notifyListeners();
  }

  static String _newSessionId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(16).toRadixString(16))
        .join();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
