import 'package:flutter/material.dart';

class CareInstructionRow extends StatelessWidget {
  final String label;
  final bool isOk;
  final String? value;
  final String? info;

  const CareInstructionRow({
    super.key,
    required this.label,
    required this.isOk,
    this.value,
    this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () =>
            _showInfoDialog(context, label, info ?? 'No information available'),
        child: Row(
          children: [

            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF64B5F6),
                  width: 1.8,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Color(0xFF64B5F6),
                ),
              ),
            ),
            const SizedBox(width: 14),


            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),


            Text(
              value ?? (isOk ? "Yes" : "No"),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isOk ? Colors.green.shade700 : Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context,
      String title,
      String description,) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black45,
      builder: (_) =>
          Dialog(
            elevation: 0,
            backgroundColor: const Color(0xFFF7FBF6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF263238),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          "Got it",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4E6F56),
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
}