/// Pure validation helpers — no Firebase calls, no UI.
/// Per DIRECTORY_GUIDE.md, this file only contains stateless functions.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final RegExp _phoneLikeRegex = RegExp(r'^[0-9+\-\s()]{4,}$');

  /// Validates the "Email address/Phone No" field on the Forgot Password
  /// screen. Currently only email is actually supported end-to-end
  /// (password reset is delivered via Firebase's email reset link), so a
  /// phone-shaped input is rejected with an explicit message rather than
  /// silently failing later inside the service call.
  static String? emailForPasswordReset(String? value) {
    final trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return 'Please enter your email address';
    }

    if (_emailRegex.hasMatch(trimmed)) {
      return null;
    }

    if (_phoneLikeRegex.hasMatch(trimmed)) {
      return "Password reset by phone isn't available yet — please use your email";
    }

    return 'Enter a valid email address';
  }

  /// General-purpose email validator for reuse elsewhere (signup, profile
  /// edit, etc.) as the app grows.
  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Please enter an email address';
    if (!_emailRegex.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }
}