import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// The one place an Inventory status (request, order, invoice, issue, asset, job…) gets its
/// colour and label, so the same status looks the same on every screen.
Color inventoryStatusColor(String status) => switch (status) {
  'approved' ||
  'issued' ||
  'fully_received' ||
  'paid' ||
  'completed' ||
  'available' ||
  'resolved' ||
  'active' => Colors.green.shade800,
  'ordered' ||
  'acknowledged' ||
  'assigned' ||
  'in_progress' => Colors.blue.shade800,
  'partially_ordered' ||
  'partially_issued' ||
  'partially_received' ||
  'partially_paid' => Colors.purple.shade800,
  'pending' || 'unpaid' => Colors.amber.shade900,
  'revision_requested' ||
  'under_maintenance' ||
  'under_repair' ||
  'waiting_for_parts' => Colors.orange.shade900,
  'rejected' ||
  'overdue' ||
  'lost' ||
  'damaged' ||
  'urgent' => Colors.red.shade800,
  'draft' || 'closed' || 'retired' || 'disposed' => Colors.blueGrey.shade800,
  _ => Colors.grey.shade700,
};

/// Display text of a status; a request sent back for changes reads "Returned".
String inventoryStatusLabel(String status) =>
    status == 'revision_requested' ? 'Returned' : humanizeStatus(status);

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
