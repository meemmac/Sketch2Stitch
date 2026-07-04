import 'package:firebase_auth/firebase_auth.dart';

/// Thrown by [AuthService] with an already user-friendly message, so
/// screens can show `e.message` directly in a SnackBar without needing
/// to know anything about Firebase error codes.
class AuthServiceException implements Exception {
  AuthServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Wraps all Firebase Auth calls. Per DIRECTORY_GUIDE.md, this is the only
/// layer allowed to talk to `FirebaseAuth.instance` directly — screens must
/// go through here instead of calling Firebase themselves.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Sends a password-reset link to [email] via Firebase Auth's built-in
  /// flow. Resolves silently on success (the UI shouldn't reveal whether
  /// the address is registered — Firebase itself no longer distinguishes
  /// this by default when email enumeration protection is enabled on the
  /// project, so don't rely on a "user-not-found" error to gate the UI).
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
      case 'user-not-found':
        // Only reachable if email enumeration protection is off for this
        // Firebase project. Kept for completeness.
        return 'No account found with that email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a bit and try again.';
      case 'network-request-failed':
        return 'Network error — check your connection and try again.';
      default:
        return 'Unable to send reset email. Please try again.';
    }
  }
}