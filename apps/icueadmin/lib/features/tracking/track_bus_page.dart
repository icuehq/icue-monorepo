import 'dart:async';

import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/reports/widgets/report_empty_state.dart';
import 'package:icueadmin/features/tracking/widgets/tracking_bus_card.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:tracking/tracking.dart';

class TrackBusPage extends StatefulWidget {
  const TrackBusPage({super.key});

  @override
  State<TrackBusPage> createState() => _TrackBusPageState();
}

class _TrackBusPageState extends State<TrackBusPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final tracking = context.read<TrackingProvider>();

      tracking.fetchFleetStatus();

      final user = auth.user;
      if (user != null) {
        tracking.initSocket(
          baseUrl: 'https://icuecloud.com',
          zoneId: user.zoneId,
          branchId: auth.selectedBranch?.id ?? user.branchId,
          organizationId: user.organizationId,
        );
      }
    });
  }

  Future<void> _handleTrackBus(VehicleSlotItem vehicle) async {
    final tracking = context.read<TrackingProvider>();

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );

    final trackUrl = await tracking.resolveLiveTrackUrl(
      routeDetailsId: vehicle.routeDetailsId,
      routeNo: vehicle.routeNo,
      mode: vehicle.mode,
    );

    if (!mounted) return;
    context.pop(); // Dismiss loading dialog

    if (trackUrl != null && trackUrl.isNotEmpty) {
      await context.push(
        AppRoutes.trackingWebview,
        extra: {
          'url': trackUrl,
          'title':
              '${vehicle.routeNo} (${vehicle.vehicleNumber}) - Live Tracking',
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Live tracking map link is unavailable for this route.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackingProvider>();
    final activeVehicles = provider.activeRunningVehicles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Track Bus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<TrackingProvider>().fetchFleetStatus(),
          ),
        ],
      ),
      body: provider.isLoading && activeVehicles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async =>
                  context.read<TrackingProvider>().fetchFleetStatus(),
              child: activeVehicles.isEmpty
                  ? ReportEmptyState(
                      icon: Icons.directions_bus_filled_outlined,
                      message: 'No buses are currently running on active trips.\nCheck back when trips commence.',
                      onRetry: () =>
                          context.read<TrackingProvider>().fetchFleetStatus(),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.15,
                          ),
                      itemCount: activeVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = activeVehicles[index];
                        return TrackingBusCard(
                          vehicle: vehicle,
                          onTap: () => _handleTrackBus(vehicle),
                        );
                      },
                    ),
            ),
    );
  }
}
