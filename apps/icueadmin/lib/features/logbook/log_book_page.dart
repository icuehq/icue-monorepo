import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';

class LogBookPage extends StatelessWidget {
  const LogBookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Book')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LogBookHubCard(
            title: 'Complaints Management',
            subtitle: 'Monitor vehicle breakdown reports, maintenance tickets, and issue resolutions.',
            icon: Icons.report_problem_rounded,
            color: Colors.red,
            onTap: () => context.push(AppRoutes.complaintsDashboard),
          ),
          const SizedBox(height: 14),
          _LogBookHubCard(
            title: 'Vehicle Cleaning Log',
            subtitle: 'Inspect fleet cleanliness, sanitize interiors/exteriors, and log daily sanitization.',
            icon: Icons.cleaning_services_rounded,
            color: Colors.teal,
            onTap: () => context.push(AppRoutes.cleaningLog),
          ),
          const SizedBox(height: 14),
          _LogBookHubCard(
            title: 'Driver Alcohol Testing',
            subtitle: 'Record daily pre-trip breathalyzer tests to ensure fleet safety and regulatory compliance.',
            icon: Icons.local_drink_rounded,
            color: Colors.indigo,
            onTap: () => context.push(AppRoutes.alcoholTestForm),
          ),
        ],
      ),
    );
  }
}

class _LogBookHubCard extends StatelessWidget {
  const _LogBookHubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
