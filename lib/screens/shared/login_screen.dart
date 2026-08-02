import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/services/auth_service.dart';
import 'package:sketch2stitch/services/user_session.dart';
import 'package:sketch2stitch/screens/shared/register_screen.dart';
import 'package:sketch2stitch/screens/shared/welcome_screen.dart';
import 'package:sketch2stitch/screens/shared/forgot_password_screen.dart';
import 'package:sketch2stitch/screens/customer/home_screen.dart';
import '../../widgets/dashboard_drawer.dart';
import '../../models/customer.dart';
import '../../models/tailor.dart';
import '../../models/retailer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _selectedUserType;
  bool _isLoading = false;

  // Top feedback state
  String? _feedbackMessage;
  Color? _feedbackColor;
  Timer? _feedbackTimer;

  final List<String> _userTypes = ['Customer', 'Retailer', 'Tailor'];

  late AnimationController _floatController;

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
    _passwordController.dispose();
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

  UserRole _getSelectedUserRole() {
    switch (_selectedUserType) {
      case 'Tailor':
        return UserRole.tailor;
      case 'Retailer':
        return UserRole.retailer;
      default:
        return UserRole.customer;
    }
  }

  Future<void> _login() async {

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    // Validate user type
    if (_selectedUserType == null) {
      _showError('Please select a user type');
      return;
    }



    setState(() => _isLoading = true);

    try {
      final credential = await AuthService().signInWithEmailAndPassword(
        email,
        password,
      );

      if (credential.user != null) {
        final role = _getSelectedUserRole();
        final profile = await AuthService().getUserProfile(
          credential.user!.uid,
          role,
        );

        if (!mounted) return;

        if (profile != null) {
          // Robust mapping from Models to DrawerProfileData
          String name = '';
          String shopName = '';
          double rating = 0.0;
          String? profilePicture;
          String? about;
          GeoPoint? location;

          if (profile is Customer) {
            name = profile.name;
            location = profile.location;
          } else if (profile is Tailor) {
            name = profile.name;
            rating = profile.rating;
            profilePicture = profile.profilePicture;
            about = profile.about;
            location = profile.location;
          } else if (profile is Retailer) {
            shopName = profile.shopName;
            name = profile.shopName; // Display shop name as primary name
            rating = profile.rating;
            profilePicture = profile.profilePicture;
            about = profile.about;
            location = profile.location;
          }

          final drawerData = DrawerProfileData(
            name: name,
            shopName: shopName,
            email: profile.email,
            phone: profile.phone,
            address: profile.address,
            rating: rating,
            location: location,
            profilePicture: profilePicture,
            about: about,
          );

          // Save to global session
          UserSession.instance.setSession(drawerData, role);

          // Navigate to home with selected role
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => UnifiedHomeScreen(
                initialRole: role,
              ),
            ),
          );
        } else {
          // Sign out if profile doesn't match role
          await AuthService().signOut();
          _showError('Profile not found for this role');
        }
      }
    } on AuthServiceException catch (e) {
      _showError(e.message);
    } catch (e) {
      debugPrint('[Login] Error: $e');
      _showError('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

              // Main content — reserved top space keeps it from ever
              // reaching the Back button, and AnimatedPadding smoothly
              // lifts it above the keyboard when typing.
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
                                // Logo — same asset used on the Welcome screen
                                Image.asset(
                                  'assets/images/transparent_logo.png',
                                  height: 48,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 16),

                                const Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Sign in to your account',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Email field
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Credential',
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
                                    hintText: 'Email or mobile number',
                                    hintStyle: const TextStyle(fontSize: 14),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
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
                                const SizedBox(height: 12),

                                // Password field
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Password',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Password',
                                    hintStyle: const TextStyle(fontSize: 14),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.lock_outline,
                                      size: 20,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
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

                                // User type dropdown
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'User Type',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                DropdownButtonFormField<String>(
                                  value: _selectedUserType,
                                  dropdownColor: const Color(0xFFDFF2DF),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  hint: const Text(
                                    'User Type',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  icon: Container(
                                    width: 20,
                                    height: 20,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDFF2DF),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  items: _userTypes.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        type,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedUserType = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 6),

                                // Forgot password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                    ),
                                    child: const Text(
                                      'Forgot password ?',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Get Started button
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
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
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Get Started',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Register link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Or ',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const RegisterScreen(),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                      ),
                                      child: const Text(
                                        'Register',
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

              // Back button - Navigates to Welcome Screen
              Positioned(
                top: 8,
                left: 8,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen(),
                      ),
                      (route) => false,
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

              // 🆕 Top Feedback Banner — Last in stack to overlay everything
              if (_feedbackMessage != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    elevation: 8,
                    color: _feedbackColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            Icon(
                              _feedbackColor == Colors.red.shade700
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _feedbackMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _feedbackMessage = null),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
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
