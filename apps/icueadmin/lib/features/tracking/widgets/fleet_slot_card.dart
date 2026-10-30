import 'package:flutter/material.dart';
import 'package:tracking/tracking.dart';

class FleetSlotCard extends StatelessWidget {
  const FleetSlotCard({
    required this.title,
    required this.category,
    required this.isActive,
    super.key,
  });

  final SlotCategory category;
  final bool isActive;
  final String title;

  void _showVehiclesSheet(
    BuildContext context,
    String statusTitle,
    Color statusColor,
    List<VehicleSlotItem> items,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.85,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: statusColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$title • $statusTitle (${items.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No vehicles in $statusTitle state.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final v = items[index];
                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  statusColor.withValues(alpha: 0.15),
                              child: Icon(
                                Icons.directions_bus_rounded,
                                color: statusColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              v.vehicleNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Driver: ${v.driverName} • ${v.driverNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Route ${v.routeNo}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActive ? Colors.blue.shade300 : Colors.grey.shade200,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.green.shade300,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'ACTIVE SLOT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${category.notStarted.length + category.inProgress.length + category.completed.length} Total',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildMetricButton(
                    context,
                    label: 'Not Started',
                    count: category.notStarted.length,
                    color: const Color(0XFFE94C3D),
                    onTap: () => _showVehiclesSheet(
                      context,
                      'Not Started',
                      const Color(0XFFE94C3D),
                      category.notStarted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricButton(
                    context,
                    label: 'In Progress',
                    count: category.inProgress.length,
                    color: const Color(0XFFFFA500),
                    onTap: () => _showVehiclesSheet(
                      context,
                      'In Progress',
                      const Color(0XFFFFA500),
                      category.inProgress,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricButton(
                    context,
                    label: 'Completed',
                    count: category.completed.length,
                    color: const Color(0XFF1DBA9B),
                    onTap: () => _showVehiclesSheet(
                      context,
                      'Completed',
                      const Color(0XFF1DBA9B),
                      category.completed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricButton(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
