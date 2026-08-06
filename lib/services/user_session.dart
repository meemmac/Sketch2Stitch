import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import '../widgets/dashboard_drawer.dart';
import 'auth_service.dart';

/// Managed the current user's session and profile data.
/// Provides real-time updates to the UI when the profile changes.
class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  /// The currently active profile.
  final ValueNotifier<DrawerProfileData?> currentProfile = ValueNotifier(null);

  /// The role of the current user.
  UserRole? _role;
  UserRole? get role => _role;

  /// The signed-in user's Firebase Auth uid, captured when the session
  /// starts. Falls back to AuthService directly in case setSession() ends
  /// up called from somewhere that races Firebase Auth's own state.
  String? _uid;
  String? get uid => _uid ?? AuthService().currentUser?.uid;

  /// Sets the active session.
  void setSession(DrawerProfileData profile, UserRole role) {
    _role = role;
    _uid = AuthService().currentUser?.uid;
    currentProfile.value = profile;
    debugPrint('[UserSession] Session started for ${profile.email} as $role (uid: $_uid)');
  }

  /// Clears the session.
  void logout() {
    _role = null;
    _uid = null;
    currentProfile.value = null;
    debugPrint('[UserSession] Session cleared');
  }

  bool get customerHasLocation => currentProfile.value?.location != null;
}