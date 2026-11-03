import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/option_card_tile.dart';

class LogBookPage extends StatelessWidget {
  const LogBookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Book')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OptionCardTile(
            title: 'Complaints Management',
            subtitle: 'Monitor vehicle breakdown reports, maintenance tickets, and issue resolutions.',
            iconAsset: 'assets/dashboard/complaints-management.png',
            onTap: () => context.push(AppRoutes.complaintsDashboard),
          ),
          OptionCardTile(
            title: 'Vehicle Cleaning Log',
            subtitle: 'Inspect fleet cleanliness, sanitize interiors/exteriors, and log daily sanitization.',
            iconAsset: 'assets/dashboard/vehicle-cleaning-log.png',
            onTap: () => context.push(AppRoutes.cleaningLog),
          ),
          OptionCardTile(
            title: 'Driver Alcohol Testing',
            subtitle: 'Record daily pre-trip breathalyzer tests to ensure fleet safety and regulatory compliance.',
            iconAsset: 'assets/dashboard/driver-alcohol-testing.png',
            onTap: () => context.push(AppRoutes.alcoholTestForm),
          ),
        ],
      ),
    );
  }
}
