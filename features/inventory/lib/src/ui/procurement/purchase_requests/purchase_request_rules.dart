import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// What this user should do next on [request], or null when nothing waits on them.
String? purchaseNextAction(
  InventoryPurchaseRequest request,
  ModuleAccess access,
  String uid,
) {
  final own = request.createdBy == uid;
  if (request.isPending && access.can('inventory.purchaseRequest.approve')) {
    return 'Awaiting your decision';
  }
  if (own && request.status == 'revision_requested') {
    return 'Returned: update and resubmit';
  }
  if (own && request.status == 'draft') return 'Draft: submit for approval';
  if (request.isOrderable && access.can('inventory.procure.operate')) {
    return 'Ready to order';
  }
  return null;
}

Color purchaseStatusColor(String status) => switch (status) {
  'approved' => Colors.green.shade800,
  'partially_ordered' => Colors.purple.shade800,
  'ordered' => Colors.blue.shade800,
  'revision_requested' => Colors.orange.shade900,
  'rejected' => Colors.red.shade800,
  'draft' => Colors.blueGrey.shade800,
  'cancelled' => Colors.grey.shade700,
  _ => Colors.amber.shade900,
};

class PurchaseStatusPill extends StatelessWidget {
  const PurchaseStatusPill(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = purchaseStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status == 'revision_requested' ? 'Returned' : humanizeStatus(status),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
