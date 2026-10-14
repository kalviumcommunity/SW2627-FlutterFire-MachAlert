import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

/// High-level authentication states for the application.
enum AppStatus { initializing, unauthenticated, authenticated }

/// Top-level application destinations.
enum AppRoute { login, signup, home }

/// Holds shared authentication, user-profile, and navigation state.
///
/// Firebase Authentication determines whether the user is signed in.
/// Firestore's users/{uid} document provides the MachAlert profile
/// including the user's role.
class AppStateProvider extends ChangeNotifier {
  AppStatus _status = AppStatus.initializing;
  AppRoute _route = AppRoute.login;
  UserModel? _user;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel?>? _profileSubscription;

  String? _activeUserUid;

  bool _isDisposed = false;

  /// Service used to read the authenticated user's Firestore profile.
  final UserService? userService;

  AppStateProvider({
    AuthService? authService,
    this.userService,
    Stream<User?>? authStream,
  }) {
    final stream = authStream ?? authService?.authStateChanges();

    if (stream != null) {
      subscribeToAuth(stream);
    }
  }

  AppStatus get status => _status;

  AppRoute get route => _route;

  UserModel? get user => _user;

  bool get isInitializing => _status == AppStatus.initializing;

  bool get isAuthenticated => _status == AppStatus.authenticated;

  bool get isUnauthenticated => _status == AppStatus.unauthenticated;

  bool get hasActiveSubscription => _authSubscription != null;

  bool get hasProfileSubscription => _profileSubscription != null;

  bool get isDisposed => _isDisposed;

  /// Starts listening to Firebase Authentication state changes.
  ///
  /// Any previous authentication subscription is cancelled first.
  void subscribeToAuth(Stream<User?> stream) {
    _authSubscription?.cancel();

    _authSubscription = stream.listen(
      _handleAuthStateChange,
      onError: (Object _) {
        if (_isDisposed) {
          return;
        }

        setUnauthenticated();
      },
    );
  }

  /// Handles login, logout, and persisted authentication events.
  void _handleAuthStateChange(User? firebaseUser) {
    if (_isDisposed) {
      return;
    }

    // Stop listening to the previous user's Firestore profile.
    _stopProfileSubscription();

    if (firebaseUser == null) {
      setUnauthenticated();
      return;
    }

    _activeUserUid = firebaseUser.uid;

    // Firebase Auth knows the UID/email but not the MachAlert role.
    // Use this as a safe temporary user until Firestore resolves
    // the complete profile.
    final fallbackUser = mapFirebaseUser(firebaseUser);

    setAuthenticated(fallbackUser);

    // Start listening to users/{uid} so role/name changes are
    // reflected automatically in the dashboard.
    if (userService != null) {
      _listenToUserProfile(firebaseUser.uid);
    }
  }

  /// Listens to the current user's Firestore profile.
  void _listenToUserProfile(String uid) {
    final service = userService;

    if (service == null) {
      return;
    }

    _profileSubscription = service
        .streamUserProfile(uid)
        .listen(
          (profile) {
            if (_isDisposed) {
              return;
            }

            // Ignore late events from a previous user session.
            if (_activeUserUid != uid) {
              return;
            }

            if (profile != null) {
              setAuthenticated(profile);
            }
          },
          onError: (Object _) {
            if (_isDisposed) {
              return;
            }

            // Keep the authenticated fallback user.
            //
            // If Firestore temporarily fails, authentication should remain valid.
            // The dashboard can safely show its unresolved-role fallback until
            // the profile becomes available.
          },
        );
  }

  /// Stops listening to the previous user's Firestore profile.
  void _stopProfileSubscription() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
  }

  /// Converts a Firebase Authentication user into a basic [UserModel].
  ///
  /// Role is intentionally empty here because roles are stored in Firestore.
  static UserModel mapFirebaseUser(User firebaseUser) {
    String? displayName;

    try {
      displayName = firebaseUser.displayName;
    } catch (_) {
      displayName = null;
    }

    String? email;

    try {
      email = firebaseUser.email;
    } catch (_) {
      email = null;
    }

    return UserModel(
      id: firebaseUser.uid,
      name: displayName ?? '',
      email: email ?? '',
      role: '',
    );
  }

  /// Marks the app as resolving its startup/authentication state.
  void setInitializing() {
    _status = AppStatus.initializing;

    notifyListeners();
  }

  /// Clears the active user and returns the application to Login.
  void setUnauthenticated({AppRoute route = AppRoute.login}) {
    _stopProfileSubscription();

    _activeUserUid = null;
    _status = AppStatus.unauthenticated;
    _user = null;
    _route = route;

    notifyListeners();
  }

  /// Marks the application as authenticated with [user].
  void setAuthenticated(UserModel user, {AppRoute route = AppRoute.home}) {
    _status = AppStatus.authenticated;
    _user = user;
    _route = route;

    notifyListeners();
  }

  /// Updates the intended top-level application destination.
  void navigateTo(AppRoute route) {
    _route = route;

    notifyListeners();
  }

  /// Clears the current application session.
  void clearSession() {
    setUnauthenticated();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    _authSubscription?.cancel();
    _profileSubscription?.cancel();

    _authSubscription = null;
    _profileSubscription = null;
    _activeUserUid = null;

    super.dispose();
  }
}
