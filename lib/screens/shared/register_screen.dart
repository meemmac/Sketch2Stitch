import 'package:flutter/material.dart';
 
enum RegisterStep { roleSelect, customerForm, tailorForm, retailerForm }
 
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
 
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}
 
class _RegisterScreenState extends State<RegisterScreen> {
  RegisterStep _step = RegisterStep.roleSelect;
  String? _selectedRole;
 
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
      body: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/register_background.png'),
            fit: BoxFit.cover,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFCDECCB), Color(0xFFEFF9EE)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Back button
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
 
              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: _buildStepContent(),
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
          backgroundColor: const Color(0xFF7CB77F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
        const SizedBox(height: 12),
        const Text(
          'Registration Form',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
 
        _buildFieldLabel('Full Name'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _customerFullNameController,
          hint: 'Full Name',
        ),
        const SizedBox(height: 16),
 
        _buildFieldLabel('Email address'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _customerEmailController,
          hint: 'Email address',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
 
        _buildFieldLabel('Phone number'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _customerPhoneController,
          hint: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 24),
 
        _buildNextButton(onPressed: () {
          // TODO: validate fields and save customer registration data
        }),
        const SizedBox(height: 16),
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
        const SizedBox(height: 12),
        const Text(
          'Registration Form',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
 
        _buildFieldLabel('Full Name'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _tailorFullNameController,
          hint: 'Full Name',
        ),
        const SizedBox(height: 16),
 
        _buildFieldLabel('Email address'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _tailorEmailController,
          hint: 'Email address',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
 
        _buildFieldLabel('Phone number'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _tailorPhoneController,
          hint: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 24),
 
        _buildNextButton(onPressed: () {
          // TODO: validate fields and save tailor registration data
        }),
        const SizedBox(height: 16),
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
        const SizedBox(height: 12),
        const Text(
          'Registration Form',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
 
        _buildFieldLabel('Shop name'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _shopNameController,
          hint: 'Shop name',
        ),
        const SizedBox(height: 16),
 
        _buildFieldLabel('Organizational email'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _orgEmailController,
          hint: 'Organizational email',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
 
        _buildFieldLabel('Phone number'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _retailerPhoneController,
          hint: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
 
        _buildFieldLabel('Shop address'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _shopAddressController,
          hint: 'Shop address',
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 24),
 
        _buildNextButton(onPressed: () {
          // TODO: validate fields and move to the next registration step
        }),
        const SizedBox(height: 16),
        _buildSignInRow(),
      ],
    );
  }

  // ---------------- Shared reusable widgets ----------------
  Widget _buildFieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
        suffixIcon: icon == null ? null : Icon(icon, size: 18, color: Colors.black54),
        filled: true,
        fillColor: const Color(0xFFBFE4C4),
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
          backgroundColor: const Color(0xFF6FAE73),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('Next', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
            // TODO: Navigate to login_screen.dart
          },
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
          child: const Text('Sign in', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
 











// class Sketch2StitchApp extends StatelessWidget {
//   const Sketch2StitchApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Sketch2Stitch',
//       debugShowCheckedModeBanner: false,
//       home: const RegisterScreen(), // <-- এটা পরিবর্তন করুন
//     );
//   }
// }