import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/validation_utils.dart';
import '../../widgets/dashboard_drawer.dart' show TopFeedbackBanner;
import '../../widgets/password_strength_indicator.dart';

/// Change-password screen, shared across all three roles (customer, tailor,
/// retailer). Reached from the profile editor that hangs off the dashboard
/// drawer.
///
/// The user confirms their current password (Firebase requires a recent
/// login before a password change anyway), then picks a new one. The strength
/// rules mirror the registration screen exactly — same regex, same
/// Weak/Medium/Strong meter — so a password that was acceptable at sign-up is
/// the same bar here.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String _passwordStrength = '';
  bool _isSaving = false;

  // Top feedback banner state — matches the registration flow and the
  // profile editor instead of a bottom SnackBar.
  String? _feedbackMessage;
  bool _feedbackIsError = false;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = false}) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
      _feedbackIsError = isError;
    });
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _feedbackMessage = null);
    });
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
    final current = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty) {
      _showFeedback('Please enter your current password.', isError: true);
      return;
    }

    if (newPassword.isEmpty) {
      _showFeedback('Please enter a new password.', isError: true);
      return;
    }

    if (!ValidationUtils.strongPasswordRegex.hasMatch(newPassword)) {
      _showFeedback(
        'Password must be at least 8 characters long and include an uppercase letter, lowercase letter, a number, and a special character.',
        isError: true,
      );
      return;
    }

    if (_passwordStrength == 'Weak') {
      _showFeedback('Please choose a stronger password.', isError: true);
      return;
    }

    if (newPassword == current) {
      _showFeedback(
        'Your new password must be different from your current one.',
        isError: true,
      );
      return;
    }

    if (confirm != newPassword) {
      _showFeedback('The two passwords do not match.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AuthService().changePassword(
        currentPassword: current,
        newPassword: newPassword,
      );
      if (!mounted) return;
      Navigator.pop(context, true); // caller shows the success banner
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showFeedback(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showFeedback('Failed to change password: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildScaffold(),
        if (_feedbackMessage != null)
          TopFeedbackBanner(
            message: _feedbackMessage!,
            isError: _feedbackIsError,
            onClose: () => setState(() => _feedbackMessage = null),
          ),
      ],
    );
  }

  Widget _buildScaffold() {
    const themeColor = Color(0xFF6C9985);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),
      appBar: AppBar(
        title: const Text(
          "Change Password",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E392A),
          ),
        ),
        backgroundColor: const Color(0xFFF7FBF7),
        foregroundColor: const Color(0xFF1E392A),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'For your security, confirm your current password before '
                'setting a new one.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _buildPasswordField(
                controller: _currentPasswordController,
                label: 'Current Password',
                hint: 'Enter your current password',
                obscureText: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'New Password',
                hint: 'Enter your new password',
                obscureText: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                showStrength: true,
                onChanged: (val) => setState(() {
                  _passwordStrength = ValidationUtils.checkPasswordStrength(
                    val,
                  );
                }),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                hint: 'Re-enter your new password',
                obscureText: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                onChanged: (_) => setState(() {}),
              ),
              if (_confirmPasswordController.text.isNotEmpty &&
                  _confirmPasswordController.text !=
                      _newPasswordController.text) ...[
                const SizedBox(height: 6),
                const Text(
                  'The two passwords do not match.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Update Password",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
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
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14),
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: Colors.grey,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: Colors.white,
            border: const OutlineInputBorder(),
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
