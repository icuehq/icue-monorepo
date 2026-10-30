import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';

class GatePassPage extends StatelessWidget {
  const GatePassPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Pass'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildActionCard(
            context,
            title: 'Generate Gate Pass',
            subtitle: 'Issue temporary campus exit or early dismissal passes',
            icon: Icons.qr_code_scanner_rounded,
            color: const Color(0XFF12967E),
            onTap: () => context.push(AppRoutes.generateGatePass),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            context,
            title: 'Pending Approval Requests',
            subtitle: 'Review, approve, or reject student gate pass applications',
            icon: Icons.pending_actions_rounded,
            color: theme.primaryColor,
            onTap: () => context.push(AppRoutes.pendingGatePass),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        onTap: onTap,
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: color,
        ),
      ),
    );
  }
}
