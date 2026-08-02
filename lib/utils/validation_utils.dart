import 'package:flutter/material.dart';




class ValidationUtils {
  // Password strength check
  static String checkPasswordStrength(String password) {
    int score = 0;




    if (password.length >= 8) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*()_\-+={}[\]:;"\u0027<>,.?/|\\]').hasMatch(password)) score++;




    if (score <= 2) return 'Weak';
    if (score == 3 || score == 4) return 'Medium';
    if (score == 5) return 'Strong';
    return '';
  }




  // Get strength color
  static Color getStrengthColor(String strength) {
    switch (strength) {
      case 'Weak': return Colors.red;
      case 'Medium': return Colors.orange;
      case 'Strong': return Colors.green;
      default: return Colors.grey;
    }
  }




  // Get strength width for progress bar
  static double getStrengthWidth(String strength) {
    switch (strength) {
      case 'Weak': return 0.33;
      case 'Medium': return 0.66;
      case 'Strong': return 1.0;
      default: return 0.0;
    }
  }




  // Strong password regex (Enforces at least 8 characters)
  static final RegExp strongPasswordRegex = RegExp(
      r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[!@#$%^&*()_\-+={}[\]:;"\u0027<>,.?/|\\]).{8,}$'
  );




  // Email validation (Robust RegExp)
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Phone validation (Digits and optional leading +)
  static bool isValidPhone(String phone) {
    return RegExp(r'^\+?\d{7,15}$').hasMatch(phone);
  }
}



