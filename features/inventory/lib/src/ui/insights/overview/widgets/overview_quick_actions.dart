import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';

/// Quick action buttons at the top of the Inventory overview.
class OverviewQuickActions extends StatelessWidget {
  const OverviewQuickActions({required this.access, super.key});

  final ModuleAccess access;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final actions = <(String, IconData, String, String, bool)>[
      (
        'Receive stock',
        Icons.move_to_inbox_outlined,
        InventoryRoutes.inventoryReceive,
        'inventory.stock.operate',
        true,
      ),
      (
        'Issue request',
        Icons.outbox_outlined,
        InventoryRoutes.inventoryRequestForm,
        'inventory.issue.request',
        false,
      ),
      (
        'Purchase request',
        Icons.request_quote_outlined,
        InventoryRoutes.inventoryPurchaseRequestForm,
        'inventory.purchaseRequest.request',
        false,
      ),
      (
        'Reports',
        Icons.assessment_outlined,
        InventoryRoutes.inventoryReports,
        'inventory.reports.view',
        false,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, icon, path, permission, isPrimary) in actions)
          if (access.can(permission))
            Material(
              color: isPrimary
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: () => context.go(path),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: isPrimary
                        ? null
                        : Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isPrimary
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isPrimary
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
