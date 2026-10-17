import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'firestore_service.dart';
import 'session_service.dart';

/// Loads the logged-in user's profile (users/{uid}) into the active session.
///
/// It watches [SessionService]: when someone logs in, it takes their user ID
/// and loads their profile from Firestore; when they log out, it clears it.
/// The profile stays live, so if it changes in the database (e.g. they edit
/// their bio), [user] updates automatically.
///
/// Usage from anywhere in the app:
///   final me = CurrentUserService.instance;
///   me.user?.displayName;   // the logged-in user's profile, or null
///   me.isLoading;           // true while the profile is being loaded
///
/// To rebuild a widget when the profile loads or changes:
///   ListenableBuilder(
///     listenable: CurrentUserService.instance,
///     builder: (context, _) =>
///         Text(CurrentUserService.instance.user?.displayName ?? 'Guest'),
///   );
///
/// Only ONE database listener is open at a time (for the logged-in user), and
/// it's replaced only when a different user logs in, so this doesn't cause
/// repeated reads no matter how many screens use it.
///
/// Note: only use this AFTER `Firebase.initializeApp(...)` has run in main().
class CurrentUserService extends ChangeNotifier {
  CurrentUserService._() {
    _session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  /// The one shared CurrentUserService for the whole app.
  static final CurrentUserService instance = CurrentUserService._();

  final SessionService _session = SessionService.instance;
  final FirestoreService _db = FirestoreService();

  StreamSubscription<AppUser?>? _subscription;
  String? _loadedUid;
  AppUser? _user;
  bool _isLoading = false;

  /// The logged-in user's profile, or null if nobody is logged in
  /// (or the profile hasn't loaded / doesn't exist yet).
  AppUser? get user => _user;

  /// True while the logged-in user's profile is being loaded.
  bool get isLoading => _isLoading;

  /// The logged-in user's ID (from the session), or null.
  String? get uid => _session.currentUid;

  /// True if someone is logged in but has no profile document in Firestore.
  bool get isMissingProfile => uid != null && !_isLoading && _user == null;

  void _onSessionChanged() {
    final uid = _session.currentUid;
    if (uid == _loadedUid) return; // same user as before, nothing to reload

    // A different user (or nobody) is now logged in: stop the old listener.
    _subscription?.cancel();
    _subscription = null;
    _loadedUid = uid;
    _user = null;

    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _db.streamUser(uid).listen(
      (profile) {
        _user = profile;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('CurrentUserService: could not load profile: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _subscription?.cancel();
    super.dispose();
  }
}
