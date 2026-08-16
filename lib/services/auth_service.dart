// services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_role.dart';
import '../models/customer.dart';
import '../models/tailor.dart';
import '../models/retailer.dart';

/// EmailJS Credentials (used for the welcome email only now)
final String _emailjsServiceId = dotenv.get('EMAILJS_SERVICE_ID', fallback: '');
final String _emailjsPublicKey = dotenv.get('EMAILJS_PUBLIC_KEY', fallback: '');
final String _emailjsAccessToken = dotenv.get('EMAILJS_ACCESS_TOKEN', fallback: '');
final String _emailjsWelcomeTemplateId = dotenv.get('EMAILJS_WELCOME_TEMPLATE_ID', fallback: '');

/// TODO: Replace with your real hosted/deep-link continue URL (see
/// ActionCodeSettings below). This is what the "return to app" link on
/// Firebase's reset-password page will point to.
const String _passwordResetContinueUrl =
    'https://sketch2stitch-276c8.web.app/reset-done.html';

/// Thrown by [AuthService] with an already user-friendly message.
class AuthServiceException implements Exception {
  AuthServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Wraps all Firebase Auth calls.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthServiceException('Failed to sign out: ${e.toString()}');
    }
  }

  // ==================== AUTHENTICATION METHODS ====================

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_messageForCode(e.code));
    } catch (e) {
      throw AuthServiceException('Login failed: ${e.toString()}');
    }
  }

  Future<({UserCredential credential, bool emailSent})> signUpWithEmailAndPassword(
    String email,
    String password,
    UserRole role,
    Map<String, dynamic> profileData,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      bool emailSent = false;
      if (credential.user != null) {
        final collection = _getCollectionForRole(role);
        await _firestore
            .collection(collection)
            .doc(credential.user!.uid)
            .set(profileData);

        final name = profileData['name'] ?? profileData['shopName'] ?? 'Member';
        emailSent = await _sendWelcomeEmailViaEmailJS(email: email, name: name, role: role);
      }

      return (credential: credential, emailSent: emailSent);
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_messageForCode(e.code));
    } catch (e) {
      throw AuthServiceException('Registration failed: ${e.toString()}');
    }
  }

  Future<UserRole?> findUserRole(String uid) async {
    try {
      final customerDoc = await _firestore.collection('Customer').doc(uid).get();
      if (customerDoc.exists) return UserRole.customer;

      final tailorDoc = await _firestore.collection('Tailor').doc(uid).get();
      if (tailorDoc.exists) return UserRole.tailor;

      final retailerDoc = await _firestore.collection('Retailer').doc(uid).get();
      if (retailerDoc.exists) return UserRole.retailer;

      return null;
    } catch (e) {
      debugPrint('Error finding user role: $e');
      return null;
    }
  }

  Future<dynamic> getUserProfile(String uid, UserRole role) async {
    try {
      final collection = _getCollectionForRole(role);
      final doc = await _firestore.collection(collection).doc(uid).get();

      if (!doc.exists) return null;

      final data = doc.data()!;

      switch (role) {
        case UserRole.customer:
          return Customer.fromJson(data);
        case UserRole.tailor:
          return Tailor.fromJson(data);
        case UserRole.retailer:
          return Retailer.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Find email by phone number - HANDLES BOTH STRING AND MAP (credential)
  Future<String?> findEmailByPhone(dynamic identifier, UserRole role) async {
    try {
      String? phoneNumber;

      // Handle different types of input
      if (identifier is String) {
        phoneNumber = identifier;
      } else if (identifier is Map<String, dynamic>) {
        // Try to extract phone number from credential map
        phoneNumber = identifier['phone'] as String? ??
            identifier['phoneNumber'] as String? ??
            identifier['credential'] as String?;

        // If phone number is not found, check if email field contains a phone number
        if (phoneNumber == null || phoneNumber.isEmpty) {
          final email = identifier['email'] as String?;
          if (email != null && !email.contains('@')) {
            phoneNumber = email;
          }
        }
      } else {
        debugPrint('⚠️ findEmailByPhone: Unknown identifier type: ${identifier.runtimeType}');
        return null;
      }

      if (phoneNumber == null || phoneNumber.trim().isEmpty) {
        debugPrint('⚠️ findEmailByPhone: Phone number is empty');
        return null;
      }

      debugPrint('📞 Searching for email with phone: $phoneNumber, role: $role');

      final collection = _getCollectionForRole(role);
      final querySnapshot = await _firestore
          .collection(collection)
          .where('phone', isEqualTo: phoneNumber.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final email = data['email'] as String?;
        debugPrint('✅ Found email: $email for phone: $phoneNumber');
        return email;
      }

      // If not found, check all collections
      final allCollections = ['Customer', 'Tailor', 'Retailer'];
      for (final coll in allCollections) {
        if (coll == collection) continue;
        final query = await _firestore
            .collection(coll)
            .where('phone', isEqualTo: phoneNumber.trim())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          final email = data['email'] as String?;
          debugPrint('✅ Found email: $email in collection: $coll');
          return email;
        }
      }

      debugPrint('❌ No email found for phone: $phoneNumber');
      return null;
    } catch (e) {
      debugPrint('❌ Error finding email by phone: $e');
      return null;
    }
  }

  /// Find email by phone number without role
  Future<String?> findEmailByPhoneNumber(String phoneNumber) async {
    try {
      if (phoneNumber.trim().isEmpty) return null;

      debugPrint('📞 Searching for email with phone: $phoneNumber (no role)');

      final allCollections = ['Customer', 'Tailor', 'Retailer'];
      for (final coll in allCollections) {
        final query = await _firestore
            .collection(coll)
            .where('phone', isEqualTo: phoneNumber.trim())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          final email = data['email'] as String?;
          debugPrint('✅ Found email: $email in collection: $coll');
          return email;
        }
      }
      debugPrint('❌ No email found for phone: $phoneNumber');
      return null;
    } catch (e) {
      debugPrint('❌ Error finding email by phone: $e');
      return null;
    }
  }

  Future<void> updateProfile(
    String uid,
    UserRole role,
    Map<String, dynamic> updates,
  ) async {
    try {
      final collection = _getCollectionForRole(role);
      await _firestore.collection(collection).doc(uid).update(updates);
    } catch (e) {
      throw AuthServiceException('Failed to update profile: ${e.toString()}');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthServiceException(
        'You are not signed in. Please log in again to change your password.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw AuthServiceException('Your current password is incorrect.');
        case 'requires-recent-login':
          throw AuthServiceException(
            'For security, please log out and log back in before changing your password.',
          );
        default:
          throw AuthServiceException(_messageForCode(e.code));
      }
    } catch (e) {
      throw AuthServiceException('Failed to change password: ${e.toString()}');
    }
  }

  // ==================== PASSWORD RESET (link-based, Firebase Spark plan) ====================

  /// Sends Firebase's built-in password-reset email (a link, not an OTP).
  /// Works entirely on the client SDK — no Cloud Functions / Blaze plan needed.
  Future<void> sendPasswordReset(String email) async {
    try {
      final trimmedEmail = email.trim();

      final emailExists = await _checkEmailExists(trimmedEmail);
      if (!emailExists) {
        throw AuthServiceException(
          'No account found with this email address.',
        );
      }

      final actionCodeSettings = ActionCodeSettings(
        url: _passwordResetContinueUrl,
        handleCodeInApp: false,
      );

      await _auth.sendPasswordResetEmail(
        email: trimmedEmail,
        actionCodeSettings: actionCodeSettings,
      );

      debugPrint('✅ Password reset email sent to $trimmedEmail');
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_messageForCode(e.code));
    } on AuthServiceException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Error in sendPasswordReset: $e');
      throw AuthServiceException(
        'Failed to send reset email. Please check your internet connection and try again.',
      );
    }
  }

  // ==================== HELPER METHODS ====================

  String _getCollectionForRole(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.tailor:
        return 'Tailor';
      case UserRole.retailer:
        return 'Retailer';
    }
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      final customerQuery = await _firestore
          .collection('Customer')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (customerQuery.docs.isNotEmpty) return true;

      final tailorQuery = await _firestore
          .collection('Tailor')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (tailorQuery.docs.isNotEmpty) return true;

      final retailerQuery = await _firestore
          .collection('Retailer')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      return retailerQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _sendWelcomeEmailViaEmailJS({
    required String email,
    required String name,
    required UserRole role,
  }) async {
    debugPrint('📧 Sending Welcome email...');

    if (_emailjsServiceId.isEmpty || _emailjsWelcomeTemplateId.isEmpty) {
      debugPrint('⚠️ EmailJS keys not configured. Skipping welcome email.');
      return false;
    }

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    try {
      final now = DateTime.now();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final formattedDate = " ${now.day} ${months[now.month - 1]} ${now.year}, ";

      final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final period = now.hour >= 12 ? 'PM' : 'AM';
      final minute = now.minute.toString().padLeft(2, '0');
      final formattedTime = "$hour:$minute $period";

      final payload = {
        'service_id': _emailjsServiceId,
        'template_id': _emailjsWelcomeTemplateId,
        'user_id': _emailjsPublicKey,
        'accessToken': _emailjsAccessToken,
        'template_params': {
          'user_name': name,
          'email': email,
          'user_email': email,
          'join_date': formattedDate,
          'join_time': formattedTime,
          'welcome_message': _getWelcomeMessageForRole(role),
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost',
        },
        body: jsonEncode(payload),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending welcome email: $e');
      return false;
    }
  }

  String _getWelcomeMessageForRole(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Welcome to Sketch2Stitch! We\'re delighted to have you with us. Discover beautiful fabrics, connect with skilled tailors, and bring your unique style to life.';
      case UserRole.tailor:
        return 'Welcome to Sketch2Stitch! Share your craftsmanship, connect with customers and turn your tailoring expertise into beautiful creations.';
      case UserRole.retailer:
        return 'Welcome to Sketch2Stitch! Showcase your quality fabrics and elements, connect with customers and build meaningful connections through our creative marketplace.';
    }
  }

  String _messageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right. Please check it.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Credentials do not match.';
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in instead.';
      case 'weak-password':
        return 'Your password is too weak. Try adding more letters or numbers.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Connection lost. Please check your internet and try again.';
      case 'operation-not-allowed':
        return 'Registration is currently unavailable. Please try again later.';
      default:
        return 'Something went wrong. Please try again in a moment.';
    }
  }
}