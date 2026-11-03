import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/option_card_tile.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const reportItems = <_ReportMenuItem>[
      _ReportMenuItem(
        title: 'Vehicle Arrival Time',
        subtitle: 'Track pickup and drop scheduled vs actual arrival times',
        iconAsset: 'assets/dashboard/vehicle-arrival-time.png',
        route: AppRoutes.arrivalTimeReport,
      ),
      _ReportMenuItem(
        title: 'Cleaning Inspection',
        subtitle: 'Review vehicle cleanliness audit checklists and photos',
        iconAsset: 'assets/dashboard/cleaning-inspection.png',
        route: AppRoutes.cleaningReport,
      ),
      _ReportMenuItem(
        title: 'Driver Alcohol Test',
        subtitle: 'Monitor breathalyzer inspection results and compliance',
        iconAsset: 'assets/dashboard/alcohol-test-report.png',
        route: AppRoutes.alcoholTestReport,
      ),
      _ReportMenuItem(
        title: 'Fuel Consumption',
        subtitle: 'Inspect monthly fuel refill logs and odometer readings',
        iconAsset: 'assets/dashboard/fuel-consumption.png',
        route: AppRoutes.fuelReport,
      ),
      _ReportMenuItem(
        title: 'Mileage Analytics',
        subtitle: 'Route distance analysis and speedometer variance',
        iconAsset: 'assets/dashboard/mileage-analytics.png',
        route: AppRoutes.mileageReport,
      ),
      _ReportMenuItem(
        title: 'Over-Speed Violations',
        subtitle: 'Examine vehicle speed threshold violations and drivers',
        iconAsset: 'assets/dashboard/over-speed-violations.png',
        route: AppRoutes.overSpeedReport,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: reportItems.length,
        itemBuilder: (context, index) {
          final item = reportItems[index];

          return OptionCardTile(
            title: item.title,
            subtitle: item.subtitle,
            iconAsset: item.iconAsset,
            onTap: () => context.push(item.route),
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
    required this.iconAsset,
    required this.route,
  });

  final String iconAsset;
  final String route;
  final String subtitle;
  final String title;
}
