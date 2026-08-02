import 'package:flutter/material.dart';
import '../utils/validation_utils.dart';




class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final String strength;




  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    required this.strength,
  });




  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();




    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ValidationUtils.getStrengthWidth(strength),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                ValidationUtils.getStrengthColor(strength),
              ),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          strength,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ValidationUtils.getStrengthColor(strength),
          ),
        ),
      ],
    );
  }
}





