import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const reportItems = <_ReportMenuItem>[
      _ReportMenuItem(
        title: 'Vehicle Arrival Time',
        subtitle: 'Track pickup and drop scheduled vs actual arrival times',
        icon: Icons.timer_outlined,
        route: AppRoutes.arrivalTimeReport,
        color: Colors.blue,
      ),
      _ReportMenuItem(
        title: 'Cleaning Inspection',
        subtitle: 'Review vehicle cleanliness audit checklists and photos',
        icon: Icons.cleaning_services_outlined,
        route: AppRoutes.cleaningReport,
        color: Colors.teal,
      ),
      _ReportMenuItem(
        title: 'Driver Alcohol Test',
        subtitle: 'Monitor breathalyzer inspection results and compliance',
        icon: Icons.local_hospital_outlined,
        route: AppRoutes.alcoholTestReport,
        color: Colors.deepOrange,
      ),
      _ReportMenuItem(
        title: 'Fuel Consumption',
        subtitle: 'Inspect monthly fuel refill logs and odometer readings',
        icon: Icons.local_gas_station_outlined,
        route: AppRoutes.fuelReport,
        color: Colors.indigo,
      ),
      _ReportMenuItem(
        title: 'Mileage Analytics',
        subtitle: 'Route distance analysis and speedometer variance',
        icon: Icons.speed_outlined,
        route: AppRoutes.mileageReport,
        color: Colors.purple,
      ),
      _ReportMenuItem(
        title: 'Over-Speed Violations',
        subtitle: 'Examine vehicle speed threshold violations and drivers',
        icon: Icons.warning_amber_rounded,
        route: AppRoutes.overSpeedReport,
        color: Colors.red,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: reportItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = reportItems[index];

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              onTap: () => context.push(item.route),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: item.color.withValues(alpha: 0.12),
                child: Icon(item.icon, color: item.color, size: 24),
              ),
              title: Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.primaryColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportMenuItem {
  const _ReportMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
  });

  final Color color;
  final IconData icon;
  final String route;
  final String subtitle;
  final String title;
}
