import 'package:flutter/material.dart';

class DriverDetailRow extends StatelessWidget {
  const DriverDetailRow({
    super.key,
    required this.title,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final String title;
  final String? value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            ':',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value != null && value!.trim().isNotEmpty ? value! : '-',
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
                color: valueColor ?? const Color(0xFF1F1D31),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
