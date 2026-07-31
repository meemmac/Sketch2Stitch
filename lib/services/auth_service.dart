import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import '../models/customer.dart';
import '../models/tailor.dart';
import '../models/retailer.dart';

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
      default:
        return 'An authentication error occurred. Please try again.';
    }
  }
}
