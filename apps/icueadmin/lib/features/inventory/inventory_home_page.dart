import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/option_grid_card.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class InventoryHomePage extends StatefulWidget {
  const InventoryHomePage({super.key});

  @override
  State<InventoryHomePage> createState() => _InventoryHomePageState();
}

class _InventoryHomePageState extends State<InventoryHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<InventoryProvider>().loadMasters(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InventoryProvider>();
    final a = p.access;
    final tiles = <(String, String, String, bool)>[
      (
        'assets/dashboard/inventory-dashboard.png',
        'Dashboard',
        AppRoutes.inventoryDashboard,
        a.can('inv.stock.view') || a.can('inv.reports.view'),
      ),
      (
        'assets/dashboard/inventory-stock-verification.png',
        'Stock verification',
        AppRoutes.inventoryVerifications,
        a.can('inv.stock.view'),
      ),
      (
        'assets/dashboard/inventory-import.png',
        'Import',
        AppRoutes.inventoryImport,
        a.can('inv.settings') ||
            a.can('inv.items.manage') ||
            a.can('inv.vendors.manage'),
      ),
      (
        'assets/dashboard/reports.png',
        'Reports',
        AppRoutes.inventoryReports,
        a.can('inv.reports.view'),
      ),
      (
        'assets/dashboard/inventory-items.png',
        'Items',
        AppRoutes.inventoryItems,
        a.can('inv.items.view'),
      ),
      (
        'assets/dashboard/inventory-categories.png',
        'Categories',
        AppRoutes.inventoryCategories,
        a.can('inv.items.view'),
      ),
      (
        'assets/dashboard/inventory-units.png',
        'Units',
        AppRoutes.inventoryUnits,
        a.can('inv.items.view'),
      ),
      (
        'assets/dashboard/inventory-stock.png',
        'Stock',
        AppRoutes.inventoryStock,
        a.can('inv.stock.view'),
      ),
      (
        'assets/dashboard/inventory-issue-requests.png',
        'Issue requests',
        AppRoutes.inventoryRequests,
        a.can('inv.issue.request') ||
            a.can('inv.issue.approve') ||
            a.can('inv.stock.view'),
      ),
      (
        'assets/dashboard/inventory-purchase-requests.png',
        'Purchase requests',
        AppRoutes.inventoryPurchaseRequests,
        a.can('inv.pr.request') ||
            a.can('inv.pr.approve') ||
            a.can('inv.procure.operate'),
      ),
      (
        'assets/dashboard/inventory-purchase-orders.png',
        'Purchase orders',
        AppRoutes.inventoryPurchaseOrders,
        a.can('inv.procure.operate') || a.can('inv.stock.operate'),
      ),
      (
        'assets/dashboard/inventory-invoices.png',
        'Vendor invoices',
        AppRoutes.inventoryInvoices,
        a.can('inv.procure.operate'),
      ),
      (
        'assets/dashboard/inventory-assets.png',
        'Assets',
        AppRoutes.inventoryAssets,
        a.can('inv.assets.view') || a.can('inv.assets.manage'),
      ),
      (
        'assets/dashboard/inventory-vendors.png',
        'Vendors',
        AppRoutes.inventoryVendors,
        a.can('inv.vendors.manage') || a.can('inv.procure.operate'),
      ),
      (
        'assets/dashboard/inventory-stores.png',
        'Stores',
        AppRoutes.inventoryStores,
        a.can('inv.stock.view') || a.can('inv.settings'),
      ),
    ];
    final visibleTiles = tiles.where((t) => t.$4).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : p.errorMessage != null
          ? Center(child: Text(p.errorMessage!))
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final int crossAxisCount;
                final double iconSize;
                final double spacing;
                final double childAspectRatio;

                if (width >= 900) {
                  crossAxisCount = 4;
                  iconSize = 88.0;
                  spacing = 16.0;
                  childAspectRatio = 1.25;
                } else if (width >= 600) {
                  crossAxisCount = 3;
                  iconSize = 84.0;
                  spacing = 14.0;
                  childAspectRatio = 1.22;
                } else if (width < 360) {
                  crossAxisCount = 2;
                  iconSize = 72.0;
                  spacing = 10.0;
                  childAspectRatio = 1.15;
                } else {
                  crossAxisCount = 2;
                  iconSize = 84.0;
                  spacing = 12.0;
                  childAspectRatio = 1.18;
                }

                return GridView.builder(
                  padding: EdgeInsets.all(spacing + 2),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: visibleTiles.length,
                  itemBuilder: (context, index) {
                    final item = visibleTiles[index];
                    return OptionGridCard(
                      title: item.$2,
                      iconAsset: item.$1,
                      iconSize: iconSize,
                      onTap: () => context.push(item.$3),
                    );
                  },
                );
              },
            ),
    );
  }
}
