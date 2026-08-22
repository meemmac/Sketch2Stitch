// screens/shared/forgot_password_screen.dart
import 'dart:async'; 
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sketch2stitch/screens/shared/login_screen.dart';
import 'package:sketch2stitch/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();

  late AnimationController _floatController;

  bool _isLoading = false;
  bool _emailSent = false;

  // Top feedback state - Same as login screen
  String? _feedbackMessage;
  Color? _feedbackColor;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _floatController.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = true}) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
      _feedbackColor = isError ? Colors.red.shade700 : Colors.green.shade700;
    });

    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  void _showError(String message) {
    _showFeedback(message, isError: true);
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showError('Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService().sendPasswordReset(email);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _emailSent = true;
      });

      _showFeedback('Reset link sent to $email!', isError: false);
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Failed to send reset email. Please try again.');
    }
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
              // Floating decorative circles
              AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) {
                  double offset = _floatController.value * 20;
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

              // Main content
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo
                                Image.asset(
                                  'assets/images/transparent_logo.png',
                                  height: 48,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 16),

                                // Title
                                Text(
                                  _emailSent ? 'Check Your Email' : 'Forgot Password?',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Subtitle
                                Text(
                                  _emailSent
                                      ? 'We\'ve sent a password reset link to\n${_emailController.text.trim()}.\nOpen the email in your mail app on this\ndevice, set a new password, then come\nback here and sign in.'
                                      : 'Enter your email and we\'ll send you a\nlink to reset your password',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Email field (only before sending)
                                if (!_emailSent) ...[
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Email Address',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Enter your email',
                                      hintStyle: const TextStyle(fontSize: 14),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        size: 20,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                if (_emailSent) ...[
                                  const Icon(
                                    Icons.mark_email_read_outlined,
                                    size: 56,
                                    color: Color(0xFF6C9985),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Action Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : (_emailSent
                                            ? () {
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const LoginScreen(),
                                                  ),
                                                );
                                              }
                                            : _sendResetLink),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            _emailSent
                                                ? 'Back to Sign In'
                                                : 'Send Reset Link',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),

                                if (_emailSent) ...[
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            setState(() => _emailSent = false);
                                          },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                    ),
                                    child: const Text(
                                      'Didn\'t get it? Try a different email',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),

                                // Navigation links
                                if (!_emailSent)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Remember your password? ',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen(),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                        ),
                                        child: const Text(
                                          'Sign in',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Back button
              Positioned(
                top: 8,
                left: 8,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              // Top Feedback Banner - Same as login screen
              if (_feedbackMessage != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _feedbackColor == Colors.red.shade700
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFC8E6C9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _feedbackColor == Colors.red.shade700
                                ? const Color(0xFFFFCDD2)
                                : const Color(0xFFA5D6A7),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _feedbackColor == Colors.red.shade700
                                  ? const Color(0xFFE53935).withValues(alpha: 0.10)
                                  : const Color(0xFF43A047).withValues(alpha: 0.10),
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
                                color: _feedbackColor == Colors.red.shade700
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF4CAF50),
                              ),
                              child: Icon(
                                _feedbackColor == Colors.red.shade700
                                    ? Icons.close_rounded
                                    : Icons.check_rounded,
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
                              onTap: () {
                                setState(() {
                                  _feedbackMessage = null;
                                });
                              },
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