import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

/// High-level application states used to coordinate authentication
/// and navigation flows.
enum AppStatus { initializing, unauthenticated, authenticated }

/// Known top-level destinations in the MachAlert application.
///
/// The actual [Route] objects remain in [AppRoutes]. This enum gives the
/// application state layer a stable, UI-independent representation of where
/// the user should be directed.
enum AppRoute { login, signup, home }

/// Holds shared application state for authentication and navigation.
///
/// Connects to [AuthService] or a [Stream<User?>] to automatically track
/// Firebase Authentication state changes and keep [AuthGate] updated.
class AppStateProvider extends ChangeNotifier {
  AppStatus _status = AppStatus.initializing;
  AppRoute _route = AppRoute.login;
  UserModel? _user;
  StreamSubscription<User?>? _authSubscription;
  bool _isDisposed = false;

  /// Creates an [AppStateProvider].
  ///
  /// Optionally accepts an [authService] or [authStream] to listen to
  /// authentication state changes. If provided, the subscription starts immediately.
  AppStateProvider({AuthService? authService, Stream<User?>? authStream}) {
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
  bool get isDisposed => _isDisposed;

  /// Subscribes to the provided authentication state stream.
  ///
  /// Cancels any previous subscription to avoid duplicate listeners.
  void subscribeToAuth(Stream<User?> stream) {
    _authSubscription?.cancel();
    _authSubscription = stream.listen(
      _handleAuthStateChange,
      onError: (Object _) {
        if (_isDisposed) return;
        // On stream failure, safely default to unauthenticated rather than
        // hanging indefinitely in initializing state.
        setUnauthenticated();
      },
    );
  }

  void _handleAuthStateChange(User? firebaseUser) {
    if (_isDisposed) return;

    if (firebaseUser != null) {
      setAuthenticated(mapFirebaseUser(firebaseUser));
    } else {
      setUnauthenticated();
    }
  }

  /// Maps a Firebase [User] to the domain [UserModel].
  ///
  /// Uses the user's UID as the identifier and handles nullable display name
  /// and email safely.
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

  /// Marks the application as waiting for its initial state to be resolved.
  void setInitializing() {
    _status = AppStatus.initializing;
    notifyListeners();
  }

  /// Sets an unauthenticated state and clears any previous user.
  void setUnauthenticated({AppRoute route = AppRoute.login}) {
    _status = AppStatus.unauthenticated;
    _user = null;
    _route = route;
    notifyListeners();
  }

  /// Sets an authenticated state and stores the application user model.
  void setAuthenticated(UserModel user, {AppRoute route = AppRoute.home}) {
    _status = AppStatus.authenticated;
    _user = user;
    _route = route;
    notifyListeners();
  }

  /// Updates the intended top-level destination without changing auth state.
  void navigateTo(AppRoute route) {
    _route = route;
    notifyListeners();
  }

  /// Clears the current session and returns the app to the login destination.
  void clearSession() {
    _status = AppStatus.unauthenticated;
    _user = null;
    _route = AppRoute.login;
    notifyListeners();
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
    _authSubscription = null;
    super.dispose();
  }
}
