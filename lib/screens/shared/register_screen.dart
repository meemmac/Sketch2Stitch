import 'package:flutter/material.dart';

enum RegisterStep { roleSelect, customerTailorForm, retailerForm }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  RegisterStep _step = RegisterStep.roleSelect;
  String? _selectedRole;

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      if (role == 'Retailer') {
        _step = RegisterStep.retailerForm;
      } else {
        _step = RegisterStep.customerTailorForm;
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
              Positioned(
                top: 10,
                right: 10,
                child: TextButton(
                  onPressed: _goBack,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  ),
                  child: const Text('Back', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                ),
              ),
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
      case RegisterStep.customerTailorForm:
        return Text('${_selectedRole ?? ''} form goes here'); // placeholder, built in a later step
      case RegisterStep.retailerForm:
        return const Text('Retailer form goes here'); // placeholder, built in a later step
    }
  }

  Widget _buildRoleSelect() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/transparent_logo.png', height: 55, fit: BoxFit.contain),
        const SizedBox(height: 16),
        const Text('Register As', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildRoleButton('Customer'),
        const SizedBox(height: 16),
        _buildRoleButton('Tailor'),
        const SizedBox(height: 16),
        _buildRoleButton('Retailer'),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Or '),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Sign in', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: Text(role, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
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