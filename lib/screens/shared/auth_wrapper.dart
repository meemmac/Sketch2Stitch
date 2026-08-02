import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/screens/customer/home_screen.dart';
import 'package:sketch2stitch/screens/shared/welcome_screen.dart';
import 'package:sketch2stitch/services/auth_service.dart';
import 'package:sketch2stitch/services/user_session.dart';
import 'package:sketch2stitch/widgets/dashboard_drawer.dart';

/// Gatekeeper widget that decides whether to show the Welcome screen
/// or the Dashboard based on Firebase Auth state.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // 1. Check connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // 2. If no user, show Welcome Screen
        if (user == null) {
          return const WelcomeScreen();
        }

        // 3. If user exists, fetch their role and profile
        return FutureBuilder(
          future: _initializeSession(user.uid, authService),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (sessionSnapshot.hasError || sessionSnapshot.data == null) {
              // Something went wrong fetching profile, force logout
              authService.signOut();
              return const WelcomeScreen();
            }

            final role = sessionSnapshot.data!;

            // 4. Navigate to the main home screen with the correct role
            return UnifiedHomeScreen(initialRole: role);
          },
        );
      },
    );
  }

  Future<UserRole?> _initializeSession(String uid, AuthService authService) async {
    try {
      // Find the user's role
      final role = await authService.findUserRole(uid);
      if (role == null) return null;

      // Fetch the full profile
      final profile = await authService.getUserProfile(uid, role);
      if (profile == null) return null;

      // Map model to DrawerProfileData
      final drawerData = DrawerProfileData(
        name: profile.name ?? '',
        shopName: role == UserRole.retailer ? (profile.shopName ?? '') : '',
        email: profile.email ?? '',
        phone: profile.phone ?? '',
        address: profile.address ?? '',
        rating: profile.rating ?? 0.0,
        location: profile.location,
        profilePicture: profile.profilePicture,
        about: profile.about ?? '',
      );

      // Save to global session
      UserSession.instance.setSession(drawerData, role);
      
      return role;
    } catch (e) {
      debugPrint('[AuthWrapper] Error initializing session: $e');
      return null;
    }
  }
}
