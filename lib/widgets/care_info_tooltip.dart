import 'package:flutter/material.dart';

class CareInstructionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isOk;
  final String? value;
  final String? info;

  const CareInstructionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.isOk,
    this.value,
    this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: isOk ? Colors.green : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isOk ? Colors.black87 : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (info != null && info!.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _showInfoDialog(context, label, info!),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C5C44).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: const Color(0xFF2C5C44),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              value ?? (isOk ? "Yes" : "No"),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOk ? Colors.green.shade800 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: const Color(0xFF2C5C44),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2C5C44).withValues(alpha: 0.08),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF2C5C44).withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.blue[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Current status: Follow these care instructions for best results',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2C5C44),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Close',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}