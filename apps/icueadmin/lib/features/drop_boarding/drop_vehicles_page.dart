import 'package:auth/auth.dart';
import 'package:drop_boarding/drop_boarding.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:icueadmin/features/drop_boarding/widgets/boarding_zone_dialog.dart';
import 'package:icueadmin/features/drop_boarding/widgets/drop_route_card.dart';
import 'package:icueadmin/features/reports/widgets/report_empty_state.dart';
import 'package:provider/provider.dart';

class DropVehiclesPage extends StatefulWidget {
  const DropVehiclesPage({super.key});

  @override
  State<DropVehiclesPage> createState() => _DropVehiclesPageState();
}

class _DropVehiclesPageState extends State<DropVehiclesPage> {
  final Set<int> _selectedRouteIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user != null) {
        final branchId = auth.selectedBranch?.id ?? user.branchId;
        final provider = context.read<DropBoardingProvider>();
        provider.fetchBoardingTypes(
          zoneId: user.zoneId,
          branchId: branchId,
          organizationId: user.organizationId,
        );
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_selectedRouteIds.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final branchId = auth.selectedBranch?.id ?? user.branchId;
    final provider = context.read<DropBoardingProvider>();

    String? selectedZone;
    if (provider.boardingTypes.isNotEmpty) {
      selectedZone = await showDialog<String>(
        context: context,
        builder: (_) =>
            BoardingZoneDialog(boardingTypes: provider.boardingTypes),
      );

      // If user cancelled the dialog, abort submission
      if (selectedZone == null) return;
    }

    final success = await provider.markVehiclesArrived(
      zoneId: user.zoneId,
      branchId: branchId,
      organizationId: user.organizationId,
      routeIds: _selectedRouteIds.toList(),
      boardingZone: selectedZone,
    );

    if (!mounted) return;

    if (success) {
      track(AppEvents.vehiclesArrived, {
        'route_count': _selectedRouteIds.length,
      });
      setState(() {
        _selectedRouteIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected vehicles marked as arrived successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ??
                'Failed to mark vehicles as arrived. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DropBoardingProvider>();
    final routes = provider.routesForDropOff;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drop-off Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final auth = context.read<AuthProvider>();
              final user = auth.user;
              if (user != null) {
                final branchId = auth.selectedBranch?.id ?? user.branchId;
                context.read<DropBoardingProvider>().fetchInitialData(
                  zoneId: user.zoneId,
                  branchId: branchId,
                  organizationId: user.organizationId,
                );
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _selectedRouteIds.isEmpty || provider.isLoading
                ? null
                : _handleSubmit,
            icon: const Icon(Icons.check_circle_outline),
            label: Text('Mark as Boarding (${_selectedRouteIds.length})'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
      body: provider.isLoading && routes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : routes.isEmpty
          ? ReportEmptyState(
              icon: Icons.check_circle_rounded,
              message: 'All drop-off vehicles have arrived.\nNo pending routes to mark.',
              onRetry: () {
                final auth = context.read<AuthProvider>();
                final user = auth.user;
                if (user != null) {
                  final branchId = auth.selectedBranch?.id ?? user.branchId;
                  context.read<DropBoardingProvider>().fetchInitialData(
                    zoneId: user.zoneId,
                    branchId: branchId,
                    organizationId: user.organizationId,
                  );
                }
              },
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: routes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final route = routes[index];
                final isSelected = _selectedRouteIds.contains(route.id);

                return DropRouteCard(
                  route: route,
                  isSelected: isSelected,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedRouteIds.add(route.id);
                      } else {
                        _selectedRouteIds.remove(route.id);
                      }
                    });
                  },
                );
              },
            ),
    );
  }
}
