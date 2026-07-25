import 'package:flutter/foundation.dart';
import '../widgets/dashboard_drawer.dart';

/// Temporary in-memory stand-in for "who's logged in and what's their
/// profile" until real auth + Firestore are wired up.
///
/// DashboardDrawer writes to this whenever a profile is saved.
/// Any other screen (e.g. CartScreen at checkout, or browsing screens
/// showing delivery charge) can read it to check things like "has this
/// customer pinned a delivery location yet?"
class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  final ValueNotifier<DrawerProfileData?> customerProfile = ValueNotifier(null);
  final ValueNotifier<DrawerProfileData?> tailorProfile = ValueNotifier(null);
  final ValueNotifier<DrawerProfileData?> retailerProfile = ValueNotifier(null);

  ValueNotifier<DrawerProfileData?> forRole(AppUserRole role) {
    switch (role) {
      case AppUserRole.customer:
        return customerProfile;
      case AppUserRole.tailor:
        return tailorProfile;
      case AppUserRole.retailer:
        return retailerProfile;
    }
  }

  bool get customerHasLocation => customerProfile.value?.location != null;
}