import 'package:auth/auth.dart';
import 'package:drop_boarding/drop_boarding.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class DropBoardingPage extends StatefulWidget {
  const DropBoardingPage({super.key});

  @override
  State<DropBoardingPage> createState() => _DropBoardingPageState();
}

class _DropBoardingPageState extends State<DropBoardingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user != null) {
        context.read<DropBoardingProvider>().fetchInitialData(
              zoneId: user.zoneId,
              branchId: auth.selectedBranch?.id ?? user.branchId,
              organizationId: user.organizationId,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drop & Boarding'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NavigationCard(
            icon: Icons.directions_bus_filled_rounded,
            title: 'Drop-off Vehicles',
            subtitle:
                'Record campus arrival of vehicles arriving from drop routes.',
            onTap: () => context.push(AppRoutes.dropVehicles),
          ),
          const SizedBox(height: 16),
          _NavigationCard(
            icon: Icons.departure_board_rounded,
            title: 'Boarding Status',
            subtitle:
                'Track parked vehicles awaiting departure and mark them as left.',
            onTap: () => context.push(AppRoutes.boarding),
          ),
        ],
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
