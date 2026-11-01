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
    final inventoryProvider = context.watch<InventoryProvider>();
    final access = inventoryProvider.access;
    final tiles = <(String, String, String, bool)>[
      (
        'assets/dashboard/inventory-dashboard.png',
        'Dashboard',
        AppRoutes.inventoryDashboard,
        access.can('inventory.stock.view') ||
            access.can('inventory.reports.view'),
      ),
      (
        'assets/dashboard/inventory-stock-verification.png',
        'Stock verification',
        AppRoutes.inventoryVerifications,
        access.can('inventory.stock.view'),
      ),
      (
        'assets/dashboard/inventory-import.png',
        'Import',
        AppRoutes.inventoryImport,
        access.can('inventory.settings') ||
            access.can('inventory.items.manage') ||
            access.can('inventory.vendors.manage'),
      ),
      (
        'assets/dashboard/reports.png',
        'Reports',
        AppRoutes.inventoryReports,
        access.can('inventory.reports.view'),
      ),
      (
        'assets/dashboard/inventory-items.png',
        'Items',
        AppRoutes.inventoryItems,
        access.can('inventory.items.view'),
      ),
      (
        'assets/dashboard/inventory-categories.png',
        'Categories',
        AppRoutes.inventoryCategories,
        access.can('inventory.items.view'),
      ),
      (
        'assets/dashboard/inventory-units.png',
        'Units',
        AppRoutes.inventoryUnits,
        access.can('inventory.items.view'),
      ),
      (
        'assets/dashboard/inventory-stock.png',
        'Stock',
        AppRoutes.inventoryStock,
        access.can('inventory.stock.view'),
      ),
      (
        'assets/dashboard/inventory-issue-requests.png',
        'Issue requests',
        AppRoutes.inventoryRequests,
        access.can('inventory.issue.request') ||
            access.can('inventory.issue.approve') ||
            access.can('inventory.stock.view'),
      ),
      (
        'assets/dashboard/inventory-purchase-requests.png',
        'Purchase requests',
        AppRoutes.inventoryPurchaseRequests,
        access.can('inventory.purchaseRequest.request') ||
            access.can('inventory.purchaseRequest.approve') ||
            access.can('inventory.procure.operate'),
      ),
      (
        'assets/dashboard/inventory-purchase-orders.png',
        'Purchase orders',
        AppRoutes.inventoryPurchaseOrders,
        access.can('inventory.procure.operate') ||
            access.can('inventory.stock.operate'),
      ),
      (
        'assets/dashboard/inventory-invoices.png',
        'Vendor invoices',
        AppRoutes.inventoryInvoices,
        access.can('inventory.procure.operate'),
      ),
      (
        'assets/dashboard/inventory-assets.png',
        'Assets',
        AppRoutes.inventoryAssets,
        access.can('inventory.assets.view') ||
            access.can('inventory.assets.manage'),
      ),
      (
        'assets/dashboard/inventory-vendors.png',
        'Vendors',
        AppRoutes.inventoryVendors,
        access.can('inventory.vendors.manage') ||
            access.can('inventory.procure.operate'),
      ),
      (
        'assets/dashboard/inventory-stores.png',
        'Stores',
        AppRoutes.inventoryStores,
        access.can('inventory.stock.view') || access.can('inventory.settings'),
      ),
    ];
    final visibleTiles = tiles.where((tile) => tile.$4).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: inventoryProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : inventoryProvider.errorMessage != null
          ? Center(child: Text(inventoryProvider.errorMessage!))
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
