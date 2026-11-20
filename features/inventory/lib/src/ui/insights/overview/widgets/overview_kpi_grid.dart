import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Headline figures of the Inventory overview, two per row on phones up to four on desktop.
class OverviewKpiGrid extends StatelessWidget {
  const OverviewKpiGrid({required this.stats, super.key});

  final Map<String, num?> stats;

  static const _tiles = <(String, String, IconData, String)>[
    (
      'items',
      'Active items',
      Icons.category_outlined,
      InventoryRoutes.inventoryItems,
    ),
    (
      'available',
      'Available stock',
      Icons.inventory_2_outlined,
      InventoryRoutes.inventoryStock,
    ),
    (
      'value',
      'Stock value',
      Icons.currency_rupee_rounded,
      InventoryRoutes.inventoryStock,
    ),
    (
      'prs',
      'Pending purchase requests',
      Icons.request_quote_outlined,
      InventoryRoutes.inventoryPurchaseRequests,
    ),
    (
      'pos',
      'Open purchase orders',
      Icons.receipt_long_outlined,
      InventoryRoutes.inventoryPurchaseOrders,
    ),
    (
      'receipts',
      'Pending goods receipts',
      Icons.move_to_inbox_outlined,
      InventoryRoutes.inventoryPurchaseOrders,
    ),
    (
      'assets',
      'Registered assets',
      Icons.devices_other_outlined,
      InventoryRoutes.inventoryAssets,
    ),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 12.0;
      final columns = (constraints.maxWidth / 190).floor().clamp(2, 4);
      final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final (key, label, icon, route) in _tiles)
            if (stats[key] != null)
              IcueKpiCard(
                label: label,
                value: key == 'value'
                    ? stats[key]!.toRupees()
                    : '${stats[key]!.round()}',
                icon: icon,
                route: route,
                width: width,
              ),
        ],
      );
    },
  );
}
