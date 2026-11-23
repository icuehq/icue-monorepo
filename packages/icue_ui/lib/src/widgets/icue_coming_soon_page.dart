import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Full page for routes an app does not have yet; [onHome] leads back to its dashboard.
class IcueComingSoonPage extends StatelessWidget {
  const IcueComingSoonPage({required this.onHome, super.key});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Coming Soon')),
    body: IcueEmptyState(
      icon: Icons.construction_rounded,
      title: 'This feature is coming soon.',
      actionLabel: 'Go To Home',
      onAction: onHome,
    ),
  );
}
