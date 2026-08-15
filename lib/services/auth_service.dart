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



/// EmailJS Credentials retrieved from environment variables
final String _emailjsServiceId = dotenv.get('EMAILJS_SERVICE_ID', fallback: '');
final String _emailjsTemplateId = dotenv.get('EMAILJS_TEMPLATE_ID', fallback: '');
final String _emailjsPublicKey = dotenv.get('EMAILJS_PUBLIC_KEY', fallback: '');
final String _emailjsAccessToken = dotenv.get('EMAILJS_ACCESS_TOKEN', fallback: '');


/// Thrown by [AuthService] with an already user-friendly message.
class AuthServiceException implements Exception {
  AuthServiceException(this.message);
  final String message;


  @override
  String toString() => message;
}


/// Wraps all Firebase Auth calls. This service handles user authentication
/// and fetching user profile data from Firestore.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;


  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;


  /// Current authenticated user.
  User? get currentUser => _auth.currentUser;


  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();


  /// Authenticate user via Firebase Auth.
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


  /// Create new account and save profile data.
  /// Returns a record with the [UserCredential] and a [bool] indicating if the welcome email was sent.
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


        // Send Welcome Email securely via EmailJS
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


  /// Merges [data] into the existing profile document for [uid] in the
  /// collection matching [role]. Only the supplied keys are overwritten —
  /// everything else in the document is left untouched.
  ///
  /// Use this from any profile-edit screen (customer/tailor/retailer) to
  /// persist changes. Throws [AuthServiceException] on failure.
  Future<void> updateProfile(
    String uid,
    UserRole role,
    Map<String, dynamic> data,
  ) async {
    try {
      final collection = _getCollectionForRole(role);
      await _firestore.collection(collection).doc(uid).update(data);
    } on FirebaseException catch (e) {
      throw AuthServiceException(
        'Failed to update profile: ${e.message ?? e.code}',
      );
    } catch (e) {
      throw AuthServiceException('Failed to update profile: ${e.toString()}');
    }
  }


  /// Changes the signed-in user's password.
  ///
  /// Firebase requires a recent login before a password change, so the
  /// [currentPassword] is used to re-authenticate first. That doubles as the
  /// "confirm it's really you" check on the change-password form.
  ///
  /// Throws [AuthServiceException] with a user-friendly message on failure.
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


  /// Handle "Forgot Password" requests.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_messageForCode(e.code));
    } catch (_) {
      throw AuthServiceException(
        'Something went wrong sending the reset email. Please try again.',
      );
    }
  }


  /// Logout user.
  Future<void> signOut() async {
    await _auth.signOut();
  }


  /// Probes Firestore to find which role collection the user belongs to.
  Future<UserRole?> findUserRole(String uid) async {
    // We check in order of expected frequency
    final customer = await _firestore.collection('Customer').doc(uid).get();
    if (customer.exists) return UserRole.customer;


    final tailor = await _firestore.collection('Tailor').doc(uid).get();
    if (tailor.exists) return UserRole.tailor;


    final retailer = await _firestore.collection('Retailer').doc(uid).get();
    if (retailer.exists) return UserRole.retailer;


    return null;
  }

  /// Attempts to find the email associated with a phone number in a specific role collection.
  Future<String?> findEmailByPhone(String phone, UserRole role) async {
    final collection = _getCollectionForRole(role);
    final query = await _firestore
        .collection(collection)
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.data()['email'] as String?;
    }
    return null;
  }


  /// Fetch user profile data from the respective Firestore collection.
  /// Returns [Customer], [Tailor], or [Retailer] if found, otherwise null.
  Future<dynamic> getUserProfile(String uid, UserRole role) async {
    try {
      final collection = _getCollectionForRole(role);
      debugPrint('[AuthService] Fetching profile from $collection for UID: $uid');
      final doc = await _firestore.collection(collection).doc(uid).get();




      if (!doc.exists || doc.data() == null) {
        debugPrint('[AuthService] No document found in $collection for UID: $uid');
        return null;
      }




      final data = doc.data()!;
      debugPrint('[AuthService] Data found: $data');
      switch (role) {
        case UserRole.customer:
          return Customer.fromJson(data, id: uid);
        case UserRole.tailor:
          return Tailor.fromJson(data, id: uid);
        case UserRole.retailer:
          return Retailer.fromJson(data, id: uid);
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }




  String _getCollectionForRole(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer'; // Singular per schema
      case UserRole.tailor:
        return 'Tailor'; // Singular per schema
      case UserRole.retailer:
        return 'Retailer'; // Singular per schema
    }
  }


  /// Sends a welcome email securely using the EmailJS API.
  /// The app only uses a Public Key, keeping your SMTP/API credentials safe.
  Future<bool> _sendWelcomeEmailViaEmailJS({
    required String email,
    required String name,
    required UserRole role,
  }) async {
    // If keys aren't configured yet, skip silently
    if (_emailjsPublicKey == 'YOUR_PUBLIC_KEY' || _emailjsPublicKey.isEmpty) {
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
      
      // Format time as HH:mm AM/PM
      final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final period = now.hour >= 12 ? 'PM' : 'AM';
      final minute = now.minute.toString().padLeft(2, '0');
      final formattedTime = "$hour:$minute $period";


      final payload = jsonEncode({
        'service_id': _emailjsServiceId,
        'template_id': _emailjsTemplateId,
        'user_id': _emailjsPublicKey,
        'accessToken': _emailjsAccessToken,
        'template_params': {
          'user_name': name,
          'email': email, // Used for the "To Email" field in Dashboard
          'user_email': email,
          'join_date': formattedDate,
          'join_time': formattedTime,
          'welcome_message': _getWelcomeMessageForRole(role),
        },
      });


      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost',
        },
        body: payload,
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
        return 'Welcome to Sketch2Stitch! We’re delighted to have you with us. Discover beautiful fabrics, connect with skilled tailors, and bring your unique style to life.';
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