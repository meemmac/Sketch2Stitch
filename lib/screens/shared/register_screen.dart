import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_screen.dart';

enum RegisterStep { roleSelect, customerForm, tailorForm, retailerForm }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  RegisterStep _step = RegisterStep.roleSelect;
  String? _selectedRole;

  late AnimationController _floatController;

  // Customer form controllers
  final _customerFullNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  // Tailor form controllers
  final _tailorFullNameController = TextEditingController();
  final _tailorEmailController = TextEditingController();
  final _tailorPhoneController = TextEditingController();

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
    _customerFullNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _tailorFullNameController.dispose();
    _tailorEmailController.dispose();
    _tailorPhoneController.dispose();
    _shopNameController.dispose();
    _orgEmailController.dispose();
    _retailerPhoneController.dispose();
    _shopAddressController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
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
                        child: _floatingCircle(120, Colors.white.withValues(alpha: 0.25)),
                      ),
                      Positioned(
                        top: 180 + offset,
                        right: -40,
                        child: _floatingCircle(90, Colors.green.shade100.withValues(alpha: 0.35)),
                      ),
                      Positioned(
                        bottom: 100 - offset,
                        left: 20,
                        child: _floatingCircle(70, Colors.white.withValues(alpha: 0.3)),
                      ),
                      Positioned(
                        bottom: 40 + offset,
                        right: 30,
                        child: _floatingCircle(50, Colors.green.shade200.withValues(alpha: 0.3)),
                      ),
                    ],
                  );
                },
              ),

              // Main content — reserved top space keeps it from ever
              // reaching the Back button, and AnimatedPadding smoothly
              // lifts it above the keyboard when typing.
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 48,
                          ),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  constraints: const BoxConstraints(maxWidth: 340),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.6),
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

              // Back button — last child so it always renders on top,
              // and the reserved top padding above keeps the card from
              // ever reaching it.
              Positioned(
                top: 10,
                right: 10,
                child: TextButton(
                  onPressed: _goBack,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
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
      height: 55,
      fit: BoxFit.contain,
    );
  }

  // ---------------- Step 1: Register As ----------------
  Widget _buildRoleSelect() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(),
        const SizedBox(height: 16),
        const Text(
          'Register As',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildRoleButton('Customer'),
        const SizedBox(height: 16),
        _buildRoleButton('Retailer'),
        const SizedBox(height: 16),
        _buildRoleButton('Tailor'),
        const SizedBox(height: 20),
        _buildSignInRow(),
      ],
    );
  }

  Widget _buildRoleButton(String role) {
    return SizedBox(
      width: double.infinity,
      height: 48,
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
            fontSize: 15,
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
        const SizedBox(height: 8),
        const Text(
          'Registration Form',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('Full name'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _customerFullNameController,
          hint: 'Full name',
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Email address'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _orgEmailController,
          hint: 'Email address',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Phone number'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _retailerPhoneController,
          hint: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Address'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _shopAddressController,
          hint: 'Address',
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 16),

        _buildNextButton(onPressed: () {
          // TODO: validate fields and move to the next registration step
        }),
        const SizedBox(height: 10),
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
        const SizedBox(height: 8),
        const Text(
          'Registration Form',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('Shop name'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _shopNameController,
          hint: 'Shop name',
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Email address'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _orgEmailController,
          hint: 'Email address',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Phone number'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _retailerPhoneController,
          hint: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Shop address'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _shopAddressController,
          hint: 'Shop address',
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 16),

        _buildNextButton(onPressed: () {
          // TODO: validate fields and save tailor registration data
        }),
        const SizedBox(height: 10),
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
        const SizedBox(height: 8),
        const Text(
          'Registration Form',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('Shop name'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _shopNameController,
          hint: 'Shop name',
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Organizational email'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _orgEmailController,
          hint: 'Organizational email',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Phone number'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _retailerPhoneController,
          hint: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),

        _buildFieldLabel('Shop address'),
        const SizedBox(height: 4),
        _buildTextField(
          controller: _shopAddressController,
          hint: 'Shop address',
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 16),

        _buildNextButton(onPressed: () {
          // TODO: validate fields and move to the next registration step
        }),
        const SizedBox(height: 10),
        _buildSignInRow(),
      ],
    );
  }

  // ---------------- Shared small widgets ----------------
  Widget _buildFieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: icon == null
            ? null
            : Container(
                margin: const EdgeInsets.all(8),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFDFF2DF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: Colors.black87),
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

  Widget _buildNextButton({required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Next',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
            children: [
        const Text('Or '),
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
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _floatingCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}