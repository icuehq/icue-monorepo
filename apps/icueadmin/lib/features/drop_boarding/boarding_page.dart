import 'package:auth/auth.dart';
import 'package:drop_boarding/drop_boarding.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/drop_boarding/widgets/boarding_vehicle_card.dart';
import 'package:icueadmin/features/reports/widgets/report_empty_state.dart';
import 'package:provider/provider.dart';

class BoardingPage extends StatefulWidget {
  const BoardingPage({super.key});

  @override
  State<BoardingPage> createState() => _BoardingPageState();
}

class _BoardingPageState extends State<BoardingPage> {
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
        provider.fetchVehicleArrivals(
          zoneId: user.zoneId,
          branchId: branchId,
          organizationId: user.organizationId,
        );
        provider.initSocket(
          baseUrl: 'https://icuecloud.com',
          branchId: branchId,
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

    final success = await provider.markVehiclesLeft(
      zoneId: user.zoneId,
      branchId: branchId,
      organizationId: user.organizationId,
      routeIds: _selectedRouteIds.toList(),
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _selectedRouteIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected vehicles marked as departed!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ??
                'Failed to update departure status. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DropBoardingProvider>();
    final vehicles = provider.arrivedVehicles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boarding Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final auth = context.read<AuthProvider>();
              final user = auth.user;
              if (user != null) {
                final branchId = auth.selectedBranch?.id ?? user.branchId;
                context.read<DropBoardingProvider>().fetchVehicleArrivals(
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
            icon: const Icon(Icons.exit_to_app_rounded),
            label: Text('Mark as Left (${_selectedRouteIds.length})'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
      body: provider.isLoading && vehicles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : vehicles.isEmpty
              ? ReportEmptyState(
                  icon: Icons.airport_shuttle_outlined,
                  message:
                      'No vehicles currently waiting in boarding zone.\nVehicles marked as arrived will appear here.',
                  onRetry: () {
                    final auth = context.read<AuthProvider>();
                    final user = auth.user;
                    if (user != null) {
                      final branchId =
                          auth.selectedBranch?.id ?? user.branchId;
                      context.read<DropBoardingProvider>().fetchVehicleArrivals(
                            zoneId: user.zoneId,
                            branchId: branchId,
                            organizationId: user.organizationId,
                          );
                    }
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vehicles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    final isSelected = _selectedRouteIds.contains(vehicle.id);

                    return BoardingVehicleCard(
                      vehicle: vehicle,
                      isSelected: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedRouteIds.add(vehicle.id);
                          } else {
                            _selectedRouteIds.remove(vehicle.id);
                          }
                        });
                      },
                    );
                  },
                ),
    );
  }
}
