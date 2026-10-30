import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/tracking/widgets/fleet_slot_card.dart';
import 'package:provider/provider.dart';
import 'package:tracking/tracking.dart';

class FleetStatusPage extends StatefulWidget {
  const FleetStatusPage({super.key});

  @override
  State<FleetStatusPage> createState() => _FleetStatusPageState();
}

class _FleetStatusPageState extends State<FleetStatusPage> {
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackingProvider>();
    final fleet = provider.fleetStatus;
    final activeSlot = fleet?.activeSlot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Operational Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<TrackingProvider>().fetchFleetStatus(),
          ),
        ],
      ),
      body: provider.isLoading && fleet == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async =>
                  context.read<TrackingProvider>().fetchFleetStatus(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context).primaryColor
                              .withValues(alpha: 0.15),
                          child: Icon(
                            Icons.speed_rounded,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Real-Time Fleet Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap any metric category to inspect vehicle assignment details.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FleetSlotCard(
                    title: 'Morning Slot',
                    isActive: activeSlot == 'Slot1',
                    category: fleet?.slot1 ?? const SlotCategory(),
                  ),
                  FleetSlotCard(
                    title: 'Afternoon Slot',
                    isActive: activeSlot == 'Slot2',
                    category: fleet?.slot2 ?? const SlotCategory(),
                  ),
                  FleetSlotCard(
                    title: 'Evening Slot',
                    isActive: activeSlot == 'Slot3',
                    category: fleet?.slot3 ?? const SlotCategory(),
                  ),
                ],
              ),
            ),
    );
  }
}
