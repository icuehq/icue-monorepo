import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Status of a gate pass request, coloured by what the server text says.
class GatePassStatusPill extends StatelessWidget {
  const GatePassStatusPill({required this.status, super.key});

  final String status;

  static (Color, IconData) _style(String status) {
    final text = status.toLowerCase();
    bool has(List<String> words) => words.any(text.contains);
    if (has(['approved', 'accepted'])) {
      return (Colors.green.shade800, Icons.check_circle_outline);
    }
    if (has(['rejected', 'denied'])) {
      return (Colors.red.shade800, Icons.cancel_outlined);
    }
    if (has(['pending', 'waiting'])) {
      return (Colors.orange.shade800, Icons.pending_outlined);
    }
    if (has(['cancelled', 'canceled'])) {
      return (Colors.grey.shade800, Icons.block_outlined);
    }
    return (Colors.blue.shade800, Icons.info_outline);
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style(status);
    return IcueStatusPill(label: status, color: color, icon: icon);
  }
}
