import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import '../widgets/dashboard_drawer.dart';

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

  /// Sets the active session.
  void setSession(DrawerProfileData profile, UserRole role) {
    _role = role;
    currentProfile.value = profile;
    debugPrint('[UserSession] Session started for ${profile.email} as $role');
  }

  /// Clears the session.
  void logout() {
    _role = null;
    currentProfile.value = null;
    debugPrint('[UserSession] Session cleared');
  }

  bool get customerHasLocation => currentProfile.value?.location != null;
}
