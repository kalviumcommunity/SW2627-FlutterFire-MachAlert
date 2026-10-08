import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

/// High-level application states used to coordinate future authentication
/// and navigation flows.
enum AppStatus {
  initializing,
  unauthenticated,
  authenticated,
}

/// Known top-level destinations in the MachAlert application.
///
/// The actual [Route] objects remain in [AppRoutes]. This enum gives the
/// application state layer a stable, UI-independent representation of where
/// the user should be directed.
enum AppRoute {
  login,
  signup,
  home,
}

/// Holds shared application state for authentication and navigation.
///
/// Authentication services can update this controller later without making
/// screens depend directly on Firebase. Day 3 intentionally keeps Firebase
/// calls out of this class; that integration belongs to the authentication
/// flow work.
class AppStateProvider extends ChangeNotifier {
  AppStatus _status = AppStatus.initializing;
  AppRoute _route = AppRoute.login;
  UserModel? _user;

  AppStatus get status => _status;
  AppRoute get route => _route;
  UserModel? get user => _user;

  bool get isInitializing => _status == AppStatus.initializing;
  bool get isAuthenticated => _status == AppStatus.authenticated;
  bool get isUnauthenticated => _status == AppStatus.unauthenticated;

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
  void setAuthenticated(
    UserModel user, {
    AppRoute route = AppRoute.home,
  }) {
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
}
