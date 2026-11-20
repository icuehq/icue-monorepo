import 'package:flutter/material.dart';

class ComplaintStatusBadge extends StatelessWidget {
  const ComplaintStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;

    switch (status.toLowerCase()) {
      case 'open':
      case 'pending':
        bg = Colors.red.shade50;
        border = Colors.red.shade200;
        text = Colors.red.shade700;
        break;
      case 'in-progress':
      case 'inprogress':
      case 'investigating':
        bg = Colors.amber.shade50;
        border = Colors.amber.shade200;
        text = Colors.amber.shade800;
        break;
      case 'resolved':
        bg = Colors.blue.shade50;
        border = Colors.blue.shade200;
        text = Colors.blue.shade700;
        break;
      case 'closed':
        bg = Colors.green.shade50;
        border = Colors.green.shade200;
        text = Colors.green.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        border = Colors.grey.shade300;
        text = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
