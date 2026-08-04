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

  // For overlay notification
  OverlayEntry? _overlayEntry;

  final AuthService _authService = AuthService();

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

  Future<void> _sendResetEmail() async {
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
      // Send password reset email using Firebase's built-in method
      await _authService.sendPasswordResetEmail(email);
      
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
      
      _showOverlayNotification(
        'Password reset email sent! Check your inbox.',
        Colors.green,
      );
      
    } on AuthServiceException catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showOverlayNotification(e.message, Colors.red);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showOverlayNotification(
        'Failed to send reset email. Please try again.',
        Colors.red,
      );
      debugPrint('Error sending reset email: $e');
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
                        child: _floatingCircle(120, Colors.white.withOpacity(0.25)),
                      ),
                      Positioned(
                        top: 180 + offset,
                        right: -40,
                        child: _floatingCircle(90, Colors.green.shade100.withOpacity(0.35)),
                      ),
                      Positioned(
                        bottom: 100 - offset,
                        left: 20,
                        child: _floatingCircle(70, Colors.white.withOpacity(0.3)),
                      ),
                      Positioned(
                        bottom: 40 + offset,
                        right: 30,
                        child: _floatingCircle(50, Colors.green.shade200.withOpacity(0.3)),
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
                                      ? 'We\'ve sent a password reset link to your email.\n\nPlease check your inbox and spam folder.'
                                      : 'Enter your email address and we\'ll send you\na link to reset your password.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Email input field (only shown when email not sent)
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
                                      contentPadding: const EdgeInsets.symmetric(
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
                                  const SizedBox(height: 8),
                                ] else ...[
                                  // Success message container
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.green.shade700,
                                          size: 48,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Email Sent Successfully!',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'We\'ve sent a password reset link to:\n${_emailController.text}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            children: [
                                              const Text(
                                                '📌 Important:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Check your spam folder if you don\'t see the email within 5 minutes.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                const SizedBox(height: 16),

                                // Action Button
                                if (!_emailSent)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _sendResetEmail,
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
                                          : const Text(
                                              'Send Reset Link',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const LoginScreen(),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Go to Sign In',
                                        style: TextStyle(
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
                                      'Remember password? ',
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