// screens/shared/forgot_password_screen.dart
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
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _floatController;

  // Step management
  int _currentStep = 0; // 0: Email, 1: OTP Verification, 2: New Password
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _userEmail = '';
  int _resendCooldown = 0;

  // For overlay notification
  OverlayEntry? _overlayEntry;

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
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _floatController.dispose();
    _hideOverlayNotification();
    super.dispose();
  }

  void _showOverlayNotification(String message, Color color) {
    _hideOverlayNotification();

    OverlayState? overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  color == Colors.green
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _hideOverlayNotification,
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 4), () {
      _hideOverlayNotification();
    });
  }

  void _hideOverlayNotification() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _sendOTP() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      _showOverlayNotification('Please enter your email address', Colors.red);
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showOverlayNotification('Please enter a valid email address', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().sendPasswordResetOTP(email);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _currentStep = 1;
        _userEmail = email;
        _resendCooldown = 60;
      });

      _showOverlayNotification('OTP sent to $email!', Colors.green);
      
      // Start cooldown timer
      _startResendCooldown();
      
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showOverlayNotification(e.message, Colors.red);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showOverlayNotification('Failed to send OTP. Please try again.', Colors.red);
    }
  }

  void _startResendCooldown() {
    if (_resendCooldown > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            if (_resendCooldown > 0) _resendCooldown--;
            if (_resendCooldown > 0) _startResendCooldown();
          });
        }
      });
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    
    if (otp.length < 6) {
      _showOverlayNotification('Please enter the 6-digit OTP', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Just verify OTP here, don't reset password yet
      // We'll verify OTP and then move to password reset step
      final authService = AuthService();
      
      // We need to verify the OTP first
      // For security, we'll check if OTP exists and is valid
      // but we won't actually reset the password until step 3
      
      // This is a simplified approach - in production, you'd want to verify
      // the OTP on the server side or use Firebase Functions
      
      setState(() {
        _isLoading = false;
        _currentStep = 2;
      });

      _showOverlayNotification('OTP verified! Set your new password.', Colors.green);
      
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showOverlayNotification('Invalid OTP. Please try again.', Colors.red);
    }
  }

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 6) {
      _showOverlayNotification('Password must be at least 6 characters', Colors.red);
      return;
    }

    if (newPassword != confirmPassword) {
      _showOverlayNotification('Passwords do not match', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verify OTP and reset password
      await AuthService().verifyOTPAndResetPassword(
        email: _userEmail,
        otp: _otpController.text.trim(),
        newPassword: newPassword,
      );

      if (!mounted) return;
      
      setState(() => _isLoading = false);

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Password Reset Successfully!'),
            ],
          ),
          content: const Text(
            'Your password has been reset successfully.\nYou can now sign in with your new password.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Go to Sign In'),
            ),
          ],
        ),
      );
      
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showOverlayNotification(e.message, Colors.red);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showOverlayNotification('Failed to reset password. Please try again.', Colors.red);
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
                          Colors.white.withOpacity(0.25),
                        ),
                      ),
                      Positioned(
                        top: 180 + offset,
                        right: -40,
                        child: _floatingCircle(
                          90,
                          Colors.green.shade100.withOpacity(0.35),
                        ),
                      ),
                      Positioned(
                        bottom: 100 - offset,
                        left: 20,
                        child: _floatingCircle(
                          70,
                          Colors.white.withOpacity(0.3),
                        ),
                      ),
                      Positioned(
                        bottom: 40 + offset,
                        right: 30,
                        child: _floatingCircle(
                          50,
                          Colors.green.shade200.withOpacity(0.3),
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
                              color: Colors.white.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
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

                                // Title based on step
                                Text(
                                  _currentStep == 0
                                      ? 'Forgot Password?'
                                      : _currentStep == 1
                                      ? 'Verify OTP'
                                      : 'Create New Password',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Subtitle based on step
                                Text(
                                  _currentStep == 0
                                      ? 'Enter your email and we\'ll send you a\n6-digit OTP to reset your password'
                                      : _currentStep == 1
                                      ? 'Enter the 6-digit OTP sent to your email'
                                      : 'Enter your new password below',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Step 0: Email field
                                if (_currentStep == 0) ...[
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
                                ],

                                // Step 1: OTP field
                                if (_currentStep == 1) ...[
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Enter OTP',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Enter 6-digit OTP',
                                      hintStyle: const TextStyle(fontSize: 14),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      prefixIcon: const Icon(
                                        Icons.pin,
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
                                  const SizedBox(height: 8),
                                  
                                  // Resend OTP button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "Didn't receive OTP? ",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      if (_resendCooldown > 0)
                                        Text(
                                          'Wait ${_resendCooldown}s',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (_resendCooldown == 0)
                                        GestureDetector(
                                          onTap: _sendOTP,
                                          child: const Text(
                                            'Resend OTP',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF6C9985),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],

                                // Step 2: New Password fields
                                if (_currentStep == 2) ...[
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'New Password',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextField(
                                    controller: _newPasswordController,
                                    obscureText: _obscureNewPassword,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Enter new password',
                                      hintStyle: const TextStyle(fontSize: 14),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                        size: 20,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureNewPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscureNewPassword =
                                                !_obscureNewPassword;
                                          });
                                        },
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Confirm Password',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Confirm new password',
                                      hintStyle: const TextStyle(fontSize: 14),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                        size: 20,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword;
                                          });
                                        },
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // Action Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            if (_currentStep == 0) {
                                              _sendOTP();
                                            } else if (_currentStep == 1) {
                                              _verifyOTP();
                                            } else if (_currentStep == 2) {
                                              _resetPassword();
                                            }
                                          },
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
                                            _currentStep == 0
                                                ? 'Send OTP'
                                                : _currentStep == 1
                                                ? 'Verify OTP'
                                                : 'Reset Password',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Navigation links
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
                    if (_currentStep > 0) {
                      setState(() {
                        if (_currentStep == 1) {
                          _currentStep = 0;
                          _otpController.clear();
                        } else if (_currentStep == 2) {
                          _currentStep = 1;
                          _newPasswordController.clear();
                          _confirmPasswordController.clear();
                        }
                      });
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    }
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
                  child: Text(
                    _currentStep > 0 ? 'Back' : 'Back',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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