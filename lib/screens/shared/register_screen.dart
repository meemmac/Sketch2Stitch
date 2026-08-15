import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_picker_screen.dart';
import '../../utils/validation_utils.dart';
import '../../widgets/password_strength_indicator.dart';

enum RegisterStep { roleSelect, customerForm, tailorForm, retailerForm }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  RegisterStep _step = RegisterStep.roleSelect;
  GeoPoint? _customerLocation;
  GeoPoint? _tailorLocation;
  GeoPoint? _retailerLocation;
  bool _locationError = false;
  bool _isLoading = false;

  // Top feedback state
  String? _feedbackMessage;
  Color? _feedbackColor;
  Timer? _feedbackTimer;

  late AnimationController _floatController;

  // Shared Account controllers
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _passwordStrength = '';

  // Customer form controllers
  final _customerFullNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _cusomerAddressController = TextEditingController();

  // Tailor form controllers
  final _tailorFullNameController = TextEditingController();
  final _tailorEmailController = TextEditingController();
  final _tailorPhoneController = TextEditingController();
  final _tailorAddressController = TextEditingController();

  // Retailer form controllers
  final _shopNameController = TextEditingController();
  final _orgEmailController = TextEditingController();
  final _retailerPhoneController = TextEditingController();
  final _shopAddressController = TextEditingController();

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
    _passwordController.dispose();
    _customerFullNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _cusomerAddressController.dispose();
    _tailorFullNameController.dispose();
    _tailorEmailController.dispose();
    _tailorPhoneController.dispose();
    _tailorAddressController.dispose();
    _orgEmailController.dispose();
    _retailerPhoneController.dispose();
    _shopAddressController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    setState(() {
      if (role == 'Retailer') {
        _step = RegisterStep.retailerForm;
      } else if (role == 'Tailor') {
        _step = RegisterStep.tailorForm;
      } else {
        _step = RegisterStep.customerForm;
      }
    });
  }

  void _goBack() {
    if (_step == RegisterStep.roleSelect) {
      Navigator.pop(context);
    } else {
      setState(() {
        _step = RegisterStep.roleSelect;
      });
    }
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

  bool _validateCommonFields(String email) {
    if (email.trim().isEmpty || !ValidationUtils.isValidEmail(email)) {
      _showError('That email address doesn\'t look right. Please check it.');
      return false;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      _showError('Password is required');
      return false;
    }

    if (!ValidationUtils.strongPasswordRegex.hasMatch(password)) {
      _showError(
        'Password must be at least 8 characters long and include an uppercase letter, lowercase letter, a number, and a special character.',
      );
      return false;
    }

    if (_passwordStrength == 'Weak') {
      _showError('Please choose a stronger password');
      return false;
    }

    return true;
  }

  bool _isFormValid() {
    // 1. Check Role-Specific Fields
    if (_step == RegisterStep.customerForm) {
      if (_customerFullNameController.text.trim().isEmpty) {
        _showError('Please enter your full name');
        return false;
      }
      if (_customerEmailController.text.trim().isEmpty) {
        _showError('Email address is required');
        return false;
      }
      if (_customerPhoneController.text.trim().isEmpty) {
        _showError('Please enter your phone number');
        return false;
      }
      if (!ValidationUtils.isValidPhone(_customerPhoneController.text.trim())) {
        _showError('Please enter a valid phone number (digits and optional +)');
        return false;
      }
      if (_cusomerAddressController.text.trim().isEmpty) {
        _showError('Please enter your address');
        return false;
      }
      if (_customerLocation == null) {
        _showError('Please pin your delivery location on the map');
        return false;
      }
    } else if (_step == RegisterStep.tailorForm) {
      if (_tailorFullNameController.text.trim().isEmpty) {
        _showError('Please enter your shop name');
        return false;
      }
      if (_tailorEmailController.text.trim().isEmpty) {
        _showError('Email address is required');
        return false;
      }
      if (_tailorPhoneController.text.trim().isEmpty) {
        _showError('Please enter your phone number');
        return false;
      }
      if (!ValidationUtils.isValidPhone(_tailorPhoneController.text.trim())) {
        _showError('Please enter a valid phone number (digits and optional +)');
        return false;
      }
      if (_tailorAddressController.text.trim().isEmpty) {
        _showError('Please enter your shop address');
        return false;
      }
      if (_tailorLocation == null) {
        _showError('Please pin your shop location on the map');
        return false;
      }
    } else if (_step == RegisterStep.retailerForm) {
      if (_shopNameController.text.trim().isEmpty) {
        _showError('Please enter your shop name');
        return false;
      }
      if (_orgEmailController.text.trim().isEmpty) {
        _showError('Organizational email is required');
        return false;
      }
      if (_retailerPhoneController.text.trim().isEmpty) {
        _showError('Please enter your phone number');
        return false;
      }
      if (!ValidationUtils.isValidPhone(_retailerPhoneController.text.trim())) {
        _showError('Please enter a valid phone number (digits and optional +)');
        return false;
      }
      if (_shopAddressController.text.trim().isEmpty) {
        _showError('Please enter your shop address');
        return false;
      }
      if (_retailerLocation == null) {
        _showError('Please pin your shop location on the map');
        return false;
      }
    }

    // 2. Check Password
    if (_passwordController.text.trim().isEmpty) {
      _showError('Please create a password');
      return false;
    }

    // 3. Run Regex/Strength Checks (re-uses _validateCommonFields logic)
    final email = _step == RegisterStep.customerForm
        ? _customerEmailController.text
        : _step == RegisterStep.tailorForm
        ? _tailorEmailController.text
        : _orgEmailController.text;

    return _validateCommonFields(email);
  }

  Future<void> _handleRegistration() async {
    if (!_isFormValid()) return;

    final email = _step == RegisterStep.customerForm
        ? _customerEmailController.text
        : _step == RegisterStep.tailorForm
        ? _tailorEmailController.text
        : _orgEmailController.text;

    UserRole role;
    Map<String, dynamic> profileData = {
      'email': email.trim(),
      'phone':
          (_step == RegisterStep.customerForm
                  ? _customerPhoneController.text
                  : _step == RegisterStep.tailorForm
                  ? _tailorPhoneController.text
                  : _retailerPhoneController.text)
              .trim(),
      'address':
          (_step == RegisterStep.customerForm
                  ? _cusomerAddressController.text
                  : _step == RegisterStep.tailorForm
                  ? _tailorAddressController.text
                  : _shopAddressController.text)
              .trim(),
    };

    if (_step == RegisterStep.customerForm) {
      role = UserRole.customer;
      profileData['name'] = _customerFullNameController.text.trim();
      profileData['location'] = _customerLocation;
      profileData['vtUsed'] = 0;
    } else if (_step == RegisterStep.tailorForm) {
      role = UserRole.tailor;
      profileData['name'] = _tailorFullNameController.text.trim();
      profileData['location'] = _tailorLocation;
      profileData['rating'] = 5.0;
    } else {
      role = UserRole.retailer;
      profileData['shopName'] = _shopNameController.text.trim();
      profileData['location'] = _retailerLocation;
      profileData['rating'] = 5.0;
      // Convert phone to number for Retailer per schema
      profileData['phone'] =
          int.tryParse(
            profileData['phone'].toString().replaceAll(RegExp(r'\D'), ''),
          ) ??
          0;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService().signUpWithEmailAndPassword(
        email.trim(),
        _passwordController.text,
        role,
        profileData,
      );

      if (!mounted) return;

      _showFeedback(
        'Registration successful! You can now log in.',
        isError: false,
      );

      // Delay navigation slightly so the user sees the green banner
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      });
    } on AuthServiceException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('An unexpected error occurred.');
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 32,
                          ),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  constraints: const BoxConstraints(
                                    maxWidth: 340,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: _buildStepContent(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Back button
              Positioned(
                top: 8,
                left: 8,
                child: TextButton(
                  onPressed: _goBack,
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

              // 🆕 Top Feedback Banner — Now the ABSOLUTE last item to ensure it sits on top of everything
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              // Glass background
                              color: _feedbackColor == Colors.red.shade700
                                  ? const Color(
                                      0xFFFFEBEE,
                                    ).withValues(alpha: 0.92)
                                  : const Color(
                                      0xFFC8E6C9,
                                    ).withValues(alpha: 0.92),

                              borderRadius: BorderRadius.circular(18),

                              // Soft border like the screenshot
                              border: Border.all(
                                color: _feedbackColor == Colors.red.shade700
                                    ? const Color(0xFFFFCDD2)
                                    : const Color(0xFF9CCC9F),
                                width: 1.2,
                              ),

                              // Soft glass shadow
                              boxShadow: [
                                BoxShadow(
                                  color: _feedbackColor == Colors.red.shade700
                                      ? const Color(
                                          0xFFD32F2F,
                                        ).withValues(alpha: 0.10)
                                      : const Color(
                                          0xFF2E7D32,
                                        ).withValues(alpha: 0.10),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),

                            child: Row(
                              children: [
                                // Icon Circle
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,

                                    color: _feedbackColor == Colors.red.shade700
                                        ? const Color(0xFFE53935)
                                        : const Color(0xFF4CAF50),

                                    border: Border.all(
                                      color:
                                          _feedbackColor == Colors.red.shade700
                                          ? const Color(0xFFEF9A9A)
                                          : const Color(0xFFA5D6A7),
                                      width: 1,
                                    ),
                                  ),

                                  child: Icon(
                                    _feedbackColor == Colors.red.shade700
                                        ? Icons.close_rounded
                                        : Icons.check_rounded,

                                    color: Colors.white,

                                    size: 20,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Message
                                Expanded(
                                  child: Text(
                                    _feedbackMessage!,
                                    style: TextStyle(
                                      color:
                                          _feedbackColor == Colors.red.shade700
                                          ? const Color(0xFF222222)
                                          : const Color(0xFF222222),

                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Close Button
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _feedbackMessage = null;
                                    });
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.black.withValues(
                                        alpha: 0.45,
                                      ),
                                      size: 18,
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case RegisterStep.roleSelect:
        return _buildRoleSelect();
      case RegisterStep.customerForm:
        return _buildCustomerForm();
      case RegisterStep.tailorForm:
        return _buildTailorForm();
      case RegisterStep.retailerForm:
        return _buildRetailerForm();
    }
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/transparent_logo.png',
      height: 46,
      fit: BoxFit.contain,
    );
  }

  // ---------------- Step 1: Register As ----------------
  Widget _buildRoleSelect() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(),
        const SizedBox(height: 12),
        const Text(
          'Register As',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        _buildRoleButton('Customer'),
        const SizedBox(height: 14),
        _buildRoleButton('Retailer'),
        const SizedBox(height: 14),
        _buildRoleButton('Tailor'),
        const SizedBox(height: 14),
        _buildSignInRow(),
      ],
    );
  }

  Widget _buildRoleButton(String role) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: () => _selectRole(role),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 130, 189, 149),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          role,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ---------------- Step 2a: Customer Form ----------------
  Widget _buildCustomerForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(),
        const SizedBox(height: 6),
        const Text(
          'Registration Form',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Full name'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _customerFullNameController,
          hint: 'Full name',
        ),
        const SizedBox(height: 7),

        _buildFieldLabel('Email address'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _customerEmailController,
          hint: 'Email address',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 7),

        _buildPasswordField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          obscureText: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          onChanged: (val) => setState(
            () =>
                _passwordStrength = ValidationUtils.checkPasswordStrength(val),
          ),
          showStrength: true,
        ),
        const SizedBox(height: 7),

        _buildFieldLabel('Phone number'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _customerPhoneController,
          hint: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
            LengthLimitingTextInputFormatter(16),
          ],
        ),
        const SizedBox(height: 7),

        _buildFieldLabel('Address'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _cusomerAddressController,
          hint: 'Address',
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 7),
        _buildLocationField(
          location: _customerLocation,
          onTap: () => _pickLocation(
            _customerLocation,
            (loc) => _customerLocation = loc,
          ),
        ),
        const SizedBox(height: 12),

        _buildNextButton(onPressed: _isLoading ? () {} : _handleRegistration),
        const SizedBox(height: 8),
        _buildSignInRow(),
      ],
    );
  }

  // ---------------- Step 2b: Tailor Form ----------------
  Widget _buildTailorForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(),
        const SizedBox(height: 6),
        const Text(
          'Registration Form',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Shop name'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _tailorFullNameController,
          hint: 'Shop name',
        ),
        const SizedBox(height: 7),

        _buildFieldLabel('Email address'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _tailorEmailController,
          hint: 'Email address',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 7),

        _buildPasswordField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          obscureText: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          onChanged: (val) => setState(
            () =>
                _passwordStrength = ValidationUtils.checkPasswordStrength(val),
          ),
          showStrength: true,
        ),
        const SizedBox(height: 7),

        _buildFieldLabel('Phone number'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _tailorPhoneController,
          hint: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
            LengthLimitingTextInputFormatter(16),
          ],
        ),
        const SizedBox(height: 7),

        _buildFieldLabel('Shop address'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _tailorAddressController,
          hint: 'Shop address',
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 7),
        _buildLocationField(
          location: _tailorLocation,
          onTap: () =>
              _pickLocation(_tailorLocation, (loc) => _tailorLocation = loc),
        ),
        const SizedBox(height: 12),
        _buildNextButton(onPressed: _isLoading ? () {} : _handleRegistration),
        const SizedBox(height: 8),
        _buildSignInRow(),
      ],
    );
  }

  // ---------------- Step 3: Retailer Form ----------------
  Widget _buildRetailerForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(),
        const SizedBox(height: 6),
        const Text(
          'Registration Form',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Shop name'),
        const SizedBox(height: 3),
        _buildTextField(controller: _shopNameController, hint: 'Shop name'),
        const SizedBox(height: 7),

        _buildFieldLabel('Organizational email'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _orgEmailController,
          hint: 'Organizational email',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 7),

        _buildPasswordField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          obscureText: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          onChanged: (val) => setState(
            () =>
                _passwordStrength = ValidationUtils.checkPasswordStrength(val),
          ),
          showStrength: true,
        ),
        const SizedBox(height: 7),

        _buildFieldLabel('Phone number'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _retailerPhoneController,
          hint: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
            LengthLimitingTextInputFormatter(16),
          ],
        ),
        const SizedBox(height: 7),

        _buildFieldLabel('Shop address'),
        const SizedBox(height: 3),
        _buildTextField(
          controller: _shopAddressController,
          hint: 'Shop address',
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 7),
        _buildLocationField(
          location: _retailerLocation,
          onTap: () => _pickLocation(
            _retailerLocation,
            (loc) => _retailerLocation = loc,
          ),
        ),
        const SizedBox(height: 12),

        _buildNextButton(onPressed: _isLoading ? () {} : _handleRegistration),
        const SizedBox(height: 8),
        _buildSignInRow(),
      ],
    );
  }

  Future<void> _pickLocation(
    GeoPoint? current,
    ValueChanged<GeoPoint> onPicked,
  ) async {
    final result = await Navigator.push<GeoPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLocation: current),
      ),
    );
    if (result != null) {
      setState(() {
        onPicked(result);
        _locationError = false;
      });
    }
  }

  Widget _buildLocationField({
    required GeoPoint? location,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Pin your location'),
        const SizedBox(height: 3),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _locationError ? Colors.red : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pin_drop_outlined,
                  size: 17,
                  color: _locationError ? Colors.red : Colors.black87,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location != null
                        ? 'Pinned: ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}'
                        : 'Tap to pin on map',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: location != null ? Colors.black87 : Colors.black45,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: Colors.black26,
                ),
              ],
            ),
          ),
        ),
        if (_locationError)
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text(
              'Please pin a location before continuing.',
              style: TextStyle(fontSize: 11, color: Colors.red),
            ),
          ),
      ],
    );
  }

  // ---------------- Shared small widgets ----------------
  Widget _buildFieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        suffixIcon: icon == null
            ? null
            : Container(
                margin: const EdgeInsets.all(5),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFDFF2DF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: Colors.black87),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
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
            _buildFieldLabel(label),
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
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (showStrength && controller.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          PasswordStrengthIndicator(
            password: controller.text,
            strength: _passwordStrength,
          ),
        ],
      ],
    );
  }

  Widget _buildNextButton({required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              const Text(
                'Submit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Or ', style: TextStyle(fontSize: 14)),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
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

class _RequirementItem extends StatelessWidget {
  final String text;
  const _RequirementItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
