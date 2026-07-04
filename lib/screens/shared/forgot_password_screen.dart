import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forgot Password',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: const ForgotPasswordPage(),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — gradient + faint FontAwesome icon pattern
          // (replaces the missing assets/images/background.png)
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

          // Blurred overlay (simulate backdrop blur)
          Container(
            color: Colors.white.withValues(alpha: 0.1),
          ),

          // Back button (top right)
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
                          FaIcon(
                            FontAwesomeIcons.arrowLeft,
                            size: 14,
                            color: Color(0xFF121212),
                          ),
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
                        Color(0x8067C090), // rgba(103,192,144,0.5)
                        Color(0xA680BE8B), // rgba(128,190,139,0.65)
                        Color(0x80FFFFFF), // rgba(255,255,255,0.5)
                        Color(0x6699BC85), // rgba(153,188,133,0.4)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xE03B4953),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 4,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo — FontAwesome icon in a circle badge
                      // (replaces the missing assets/images/logo.png)
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
                          child: FaIcon(
                            FontAwesomeIcons.key,
                            size: 32,
                            color: Color(0xFF2D4340),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Title
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

                      // Subtitle
                      const Text(
                        'An OTP will be sent to your email/message to\nreset your Password',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 28),

                      // Input label
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Email address/Phone No',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Email/Phone input field
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB0D19D),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF2D4340),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Email / Phone',
                            hintStyle: TextStyle(
                              color: Color(0xFF2D4340),
                              fontSize: 18,
                            ),
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 20, right: 12),
                              child: FaIcon(
                                FontAwesomeIcons.envelope,
                                size: 18,
                                color: Color(0xFF2D4340),
                              ),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Send OTP button
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () {
                            // Handle Send OTP
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF86B46B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Send OTP',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              SizedBox(width: 12),
                              FaIcon(
                                FontAwesomeIcons.arrowRight,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Or Sign in
                      RichText(
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}