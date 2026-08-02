import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_role.dart';
import '../models/customer.dart';
import '../models/tailor.dart';
import '../models/retailer.dart';

/// EmailJS Credentials - TODO: Replace with your actual IDs from EmailJS Dashboard
const String _emailjsServiceId = 'service_k4v23nj';
const String _emailjsTemplateId = 'template_cj9ca0n';
const String _emailjsPublicKey = 'fkv1tJuqoVoD2O5Ey';
const String _emailjsAccessToken = 'WczQoC1tFzLQrIhcbLI6J'; //Your Access Token

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
      final payload = jsonEncode({
        'service_id': _emailjsServiceId,
        'template_id': _emailjsTemplateId,
        'user_id': _emailjsPublicKey,
        'accessToken': _emailjsAccessToken,
        'template_params': {
          'user_name': name,
          'email': email,
          'user_email': email,
          'user_role': role.name.toUpperCase(),
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
        return 'Welcome to Sketch Stitch! Start exploring premium fabrics and expert tailors to create your perfect outfit.';
      case UserRole.tailor:
        return 'Welcome to our professional network! We are excited to have you on board to provide expert tailoring services to our customers.';
      case UserRole.retailer:
        return 'Welcome to the marketplace! Start listing your high-quality fabrics and elements to reach thousands of customers.';
    }
  }

  String _messageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a bit and try again.';
      case 'network-request-failed':
        return 'Network error — check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email and password authentication is not enabled in Firebase Console.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }
}
