// screens/shared/reset_password_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sketch2stitch/screens/shared/login_screen.dart';
import 'package:sketch2stitch/services/auth_service.dart';
import 'package:sketch2stitch/utils/validation_utils.dart';
import 'package:sketch2stitch/widgets/password_strength_indicator.dart';

/// The second half of "forgot password", handled **inside the app**.
///
/// Firebase's reset email points at `public/action.html` (set as the
/// project's custom action URL). That page bounces straight back here as
/// `sketch2stitch://reset?oobCode=...`, so the user never types their new
/// password on Firebase's un-styleable web form — and we get to enforce the
/// same strength rules as registration and [ChangePasswordScreen], which
/// Firebase itself can't do on the free Spark plan.
///
/// Everything here is plain client-SDK: `verifyPasswordResetCode` +
/// `confirmPasswordReset`. No Cloud Functions, no Blaze upgrade.
class ResetPasswordScreen extends StatefulWidget {
  final String oobCode;

  const ResetPasswordScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late AnimationController _floatController;

  /// Null while the code is still being checked, then the address the link
  /// belongs to — shown so the user knows which account they're resetting.
  String? _email;
  bool _isVerifying = true;
  String? _linkError;

  bool _isSaving = false;
  bool _done = false;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _passwordStrength = '';

  // Same top banner as the login / forgot-password screens.
  String? _feedbackMessage;
  bool _feedbackIsError = true;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _verifyCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _floatController.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = true}) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
      _feedbackIsError = isError;
    });
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _feedbackMessage = null);
    });
  }

  /// Reset links are single-use and expire, so check the code before showing
  /// the form — otherwise the user types a password only to be rejected.
  Future<void> _verifyCode() async {
    try {
      final email = await AuthService().verifyPasswordResetCode(widget.oobCode);
      if (!mounted) return;
      setState(() {
        _email = email;
        _isVerifying = false;
      });
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _linkError = e.message;
        _isVerifying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _linkError = 'Could not open this reset link. Please request a new one.';
        _isVerifying = false;
      });
    }
  }

  void _showPasswordRequirements() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.green),
            SizedBox(width: 10),
            Text('Strong Password'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To keep your account safe, please use at least:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            SizedBox(height: 12),
            _RequirementItem('At least 8 characters long'),
            _RequirementItem('One uppercase letter (A-Z)'),
            _RequirementItem('One lowercase letter (a-z)'),
            _RequirementItem('One number (0-9)'),
            _RequirementItem('One special character (!@#\$%^&*)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty) {
      _showFeedback('Please enter a new password.');
      return;
    }

    // Firebase only rejects passwords under 6 characters, so the app's own
    // rule — identical to registration and the change-password screen — is
    // enforced right here.
    if (!ValidationUtils.strongPasswordRegex.hasMatch(password)) {
      _showFeedback(
        'Password must be at least 8 characters long and include an uppercase '
        'letter, lowercase letter, a number, and a special character.',
      );
      return;
    }

    if (_passwordStrength == 'Weak') {
      _showFeedback('Please choose a stronger password.');
      return;
    }

    if (confirm != password) {
      _showFeedback('The two passwords do not match.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AuthService().confirmPasswordReset(
        code: widget.oobCode,
        newPassword: password,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _done = true;
      });
      _showFeedback('Password updated. You can sign in now.', isError: false);
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showFeedback(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showFeedback('Could not reset your password. Please try again.');
    }
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFCDECCB), Color(0xFFEFF9EE)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) {
                  final offset = _floatController.value * 20;
                  return Stack(
                    children: [
                      Positioned(
                        top: 60 - offset,
                        left: -30,
                        child: _floatingCircle(
                          120,
                          Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      Positioned(
                        top: 180 + offset,
                        right: -40,
                        child: _floatingCircle(
                          90,
                          Colors.green.shade100.withValues(alpha: 0.35),
                        ),
                      ),
                      Positioned(
                        bottom: 100 - offset,
                        left: 20,
                        child: _floatingCircle(
                          70,
                          Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      Positioned(
                        bottom: 40 + offset,
                        right: 30,
                        child: _floatingCircle(
                          50,
                          Colors.green.shade200.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  );
                },
              ),

              Padding(
                padding: const EdgeInsets.only(top: 56),
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                            ),
                            child: _buildCardContent(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (_feedbackMessage != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildBanner(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/transparent_logo.png',
          height: 48,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
        if (_isVerifying)
          ..._verifyingContent()
        else if (_linkError != null)
          ..._errorContent()
        else if (_done)
          ..._doneContent()
        else
          ..._formContent(),
      ],
    );
  }

  List<Widget> _verifyingContent() => const [
        Text(
          'Checking your link…',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20),
        CircularProgressIndicator(color: Color(0xFF6C9985)),
        SizedBox(height: 12),
      ];

  List<Widget> _errorContent() => [
        const Text(
          'Link No Longer Valid',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _linkError!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        const Icon(
          Icons.link_off_rounded,
          size: 56,
          color: Color(0xFF6C9985),
        ),
        const SizedBox(height: 16),
        _primaryButton('Back to Sign In', _goToLogin),
      ];

  List<Widget> _doneContent() => [
        const Text(
          'Password Updated',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your new password is saved. Sign in to\ncontinue.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        const Icon(
          Icons.lock_reset_rounded,
          size: 56,
          color: Color(0xFF6C9985),
        ),
        const SizedBox(height: 16),
        _primaryButton('Sign In', _goToLogin),
      ];

  List<Widget> _formContent() => [
        const Text(
          'Set a New Password',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a new password for\n${_email ?? ''}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        _passwordField(
          controller: _passwordController,
          label: 'New Password',
          hint: 'Enter your new password',
          obscure: _obscurePassword,
          onToggle: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          showStrength: true,
          onChanged: (val) => setState(() {
            _passwordStrength = ValidationUtils.checkPasswordStrength(val);
          }),
        ),
        const SizedBox(height: 14),
        _passwordField(
          controller: _confirmController,
          label: 'Confirm New Password',
          hint: 'Re-enter your new password',
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          onChanged: (_) => setState(() {}),
        ),
        if (_confirmController.text.isNotEmpty &&
            _confirmController.text != _passwordController.text) ...[
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'The two passwords do not match.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _primaryButton('Save New Password', _isSaving ? null : _submit,
            busy: _isSaving),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _isSaving ? null : _goToLogin,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
          ),
          child: const Text(
            'Cancel and sign in instead',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ];

  Widget _primaryButton(String label, VoidCallback? onPressed,
      {bool busy = false}) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    ValueChanged<String>? onChanged,
    bool showStrength = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showStrength) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _showPasswordRequirements,
                child: const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: Colors.grey,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (showStrength && controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          PasswordStrengthIndicator(
            password: controller.text,
            strength: _passwordStrength,
          ),
        ],
      ],
    );
  }

  Widget _buildBanner() {
    final isError = _feedbackIsError;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFC8E6C9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isError
                  ? const Color(0xFFFFCDD2)
                  : const Color(0xFFA5D6A7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isError
                        ? const Color(0xFFE53935)
                        : const Color(0xFF43A047))
                    .withValues(alpha: 0.10),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isError
                      ? const Color(0xFFE53935)
                      : const Color(0xFF4CAF50),
                ),
                child: Icon(
                  isError ? Icons.close_rounded : Icons.check_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _feedbackMessage!,
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _feedbackMessage = null),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.black.withValues(alpha: 0.55),
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// A single bullet in the password-requirements dialog.
class _RequirementItem extends StatelessWidget {
  final String text;

  const _RequirementItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
