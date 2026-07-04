import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../services/auth_service.dart';
import '../../../utils/validators.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isSending = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    // Screens don't talk to Firebase directly — validate locally, then
    // delegate the actual work to AuthService.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSending = true);

    try {
      await _authService.sendPasswordResetEmail(_controller.text);
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _emailSent = true;
      });
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red[700]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — gradient + faint FontAwesome icon pattern
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2D4340),
                  Color(0xFF67C090),
                ],
              ),
            ),
          ),
          Positioned(
            left: -40,
            top: 60,
            child: Opacity(
              opacity: 0.12,
              child: FaIcon(
                FontAwesomeIcons.shieldHalved,
                size: 220,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: 40,
            child: Opacity(
              opacity: 0.12,
              child: FaIcon(
                FontAwesomeIcons.lock,
                size: 180,
                color: Colors.white,
              ),
            ),
          ),
          Container(color: Colors.white.withValues(alpha: 0.1)),

          // Back button
          Positioned(
            top: 20,
            right: 20,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF67C090),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(FontAwesomeIcons.arrowLeft,
                              size: 14, color: Color(0xFF121212)),
                          SizedBox(width: 8),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF121212),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Center card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 44, vertical: 40),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.08, 0.31, 0.58, 0.78],
                      colors: [
                        Color(0x8067C090),
                        Color(0xA680BE8B),
                        Color(0x80FFFFFF),
                        Color(0x6699BC85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xE03B4953), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 4,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _emailSent ? _buildSuccessState() : _buildFormState(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: FaIcon(FontAwesomeIcons.key,
                  size: 32, color: Color(0xFF2D4340)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            "We'll email you a link to reset your password",
            style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Email address',
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFB0D19D),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextFormField(
              controller: _controller,
              enabled: !_isSending,
              keyboardType: TextInputType.emailAddress,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: Validators.emailForPasswordReset,
              style: const TextStyle(fontSize: 18, color: Color(0xFF2D4340)),
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                hintStyle: TextStyle(color: Color(0xFF2D4340), fontSize: 18),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 20, right: 12),
                  child: FaIcon(FontAwesomeIcons.envelope,
                      size: 18, color: Color(0xFF2D4340)),
                ),
                prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: InputBorder.none,
                errorStyle: TextStyle(
                  color: Color(0xFF7A1F1F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _isSending ? null : _handleSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF86B46B),
                disabledBackgroundColor:
                    const Color(0xFF86B46B).withValues(alpha: 0.6),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Send Reset Link',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                        SizedBox(width: 12),
                        FaIcon(FontAwesomeIcons.arrowRight,
                            color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 18, color: Colors.black),
                children: [
                  TextSpan(text: 'Or '),
                  TextSpan(
                    text: 'Sign in',
                    style: TextStyle(
                      color: Color(0xFF00063E),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          child: const Center(
            child: FaIcon(FontAwesomeIcons.solidEnvelopeOpen,
                size: 30, color: Color(0xFF2D4340)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: 'Inter',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "If an account exists for ${_controller.text.trim()}, "
          "a password reset link is on its way. It can take a minute "
          "to arrive — check spam too.",
          style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: OutlinedButton(
            onPressed: () => setState(() => _emailSent = false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2D4340)),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text(
              'Use a different email',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D4340),
              ),
            ),
          ),
        ),
      ],
    );
  }
}