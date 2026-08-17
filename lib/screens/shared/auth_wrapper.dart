// screens/auth_wrapper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/models/customer.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/screens/customer/home_screen.dart';
import 'package:sketch2stitch/screens/shared/welcome_screen.dart';
import 'package:sketch2stitch/services/auth_service.dart';
import 'package:sketch2stitch/services/user_session.dart';
import 'package:sketch2stitch/widgets/dashboard_drawer.dart';
import '../../models/customer.dart';
import '../../models/tailor.dart';
import '../../models/retailer.dart';

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


      // Build DrawerProfileData based on role type
      final drawerData = _buildDrawerProfileData(profile, role);
      
      // Save to global session using UserSess
      // Robust mapping from Models to DrawerProfileData
      String name = '';
      String shopName = '';
      String email = '';
      String phone = '';
      String address = '';
      double rating = 0.0;
      String? profilePicture;
      String? about;
      GeoPoint? location;

      if (profile is Customer) {
        name = profile.name;
        email = profile.email;
        phone = profile.phone;
        address = profile.address;
        location = profile.location;
        // Customers have no rating/about/picture in model
      } else if (profile is Tailor) {
        name = profile.name;
        email = profile.email;
        phone = profile.phone;
        address = profile.address;
        rating = profile.rating;
        profilePicture = profile.profilePicture;
        about = profile.about;
        location = profile.location;
      } else if (profile is Retailer) {
        shopName = profile.shopName;
        name = profile.shopName;
        email = profile.email;
        phone = profile.phone;
        address = profile.address;
        rating = profile.rating;
        profilePicture = profile.profilePicture;
        about = profile.about;
        location = profile.location;
      }

      final drawerData = DrawerProfileData(
        name: name,
        shopName: shopName,
        email: email,
        phone: phone,
        address: address,
        rating: rating,
        location: location,
        profilePicture: profilePicture,
        about: about ?? '',
      );

      // Save to global session
>>>>>>> 5f06b31bdb501219404a73b1d597e016f049bfd7
      UserSession.instance.setSession(drawerData, role, uid: uid);
      
      return role;
    } catch (e) {
      debugPrint('[AuthWrapper] Error initializing session: $e');
      // Clear session on error
      UserSession.instance.logout();
      return null;
    }
  }

  /// Helper method to build DrawerProfileData based on role
  DrawerProfileData _buildDrawerProfileData(dynamic profile, UserRole role) {
    // Default values
    String name = '';
    String shopName = '';
    String email = '';
    String phone = '';
    String address = '';
    double rating = 0.0;
    dynamic location;
    String? profilePicture;
    String about = '';

    switch (role) {
      case UserRole.customer:
        final customer = profile as Customer;
        name = customer.name;
        email = customer.email;
        phone = customer.phone;
        address = customer.address;
        location = customer.location;
        // Customer has NO rating field - keep as 0.0
        rating = 0.0;
        // Customer doesn't have these fields
        profilePicture = null;
        about = '';
        break;

      case UserRole.tailor:
        final tailor = profile as Tailor;
        name = tailor.name;
        email = tailor.email;
        phone = tailor.phone;
        address = tailor.address;
        rating = tailor.rating;
        location = tailor.location;
        profilePicture = tailor.profilePicture;
        about = tailor.about ?? '';
        break;

      case UserRole.retailer:
        final retailer = profile as Retailer;
        shopName = retailer.shopName;
        name = retailer.shopName;
        email = retailer.email;
        phone = retailer.phone;
        address = retailer.address;
        rating = retailer.rating;
        location = retailer.location;
        profilePicture = retailer.profilePicture;
        about = retailer.about ?? '';
        break;
    }

    return DrawerProfileData(
      name: name,
      shopName: shopName,
      email: email,
      phone: phone,
      address: address,
      rating: rating,
      location: location,
      profilePicture: profilePicture,
      about: about,
    );
  }
}