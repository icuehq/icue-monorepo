import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// The one place an Inventory status (request, order, invoice, issue, asset, job…) gets its
/// colour and label, so the same status looks the same on every screen.
Color inventoryStatusColor(String status) => switch (status) {
  'approved' ||
  'issued' ||
  'received' ||
  'completed' ||
  'available' ||
  'resolved' ||
  'active' ||
  'in_stock' ||
  'in_date' => Colors.green.shade800,
  'open' ||
  'acknowledged' ||
  'assigned' ||
  'in_progress' => Colors.blue.shade800,
  'partially_issued' || 'partially_received' => Colors.purple.shade800,
  'pending' || 'unregistered' || 'low_stock' => Colors.amber.shade900,
  'under_maintenance' ||
  'under_repair' ||
  'waiting_for_parts' ||
  'expiring_soon' ||
  'high' => Colors.orange.shade900,
  'rejected' ||
  'overdue' ||
  'lost' ||
  'damaged' ||
  'urgent' ||
  'out_of_stock' ||
  'expired' => Colors.red.shade800,
  'closed' || 'retired' || 'disposed' => Colors.blueGrey.shade800,
  _ => Colors.grey.shade700,
};

/// Display text of a status.
String inventoryStatusLabel(String status) => humanizeStatus(status);

class InventoryStatusChip extends StatelessWidget {
  const InventoryStatusChip(this.status, {super.key});

  /// Raw status value, e.g. `partially_received`.
  final String status;

  @override
  Widget build(BuildContext context) => IcueStatusPill(
    label: inventoryStatusLabel(status),
    color: inventoryStatusColor(status),
    compact: true,
  );
}
