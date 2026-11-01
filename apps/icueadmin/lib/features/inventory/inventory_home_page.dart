import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
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
    final tiles = <(IconData, String, String, bool)>[
      (
        Icons.inventory_2_rounded,
        'Items',
        AppRoutes.inventoryItems,
        a.can('inv.items.view'),
      ),
      (
        Icons.category_rounded,
        'Categories',
        AppRoutes.inventoryCategories,
        a.can('inv.items.view'),
      ),
      (
        Icons.straighten_rounded,
        'Units',
        AppRoutes.inventoryUnits,
        a.can('inv.items.view'),
      ),
      (
        Icons.bar_chart_rounded,
        'Stock',
        AppRoutes.inventoryStock,
        a.can('inv.stock.view'),
      ),
      (
        Icons.assignment_rounded,
        'Issue requests',
        AppRoutes.inventoryRequests,
        a.can('inv.issue.request') ||
            a.can('inv.issue.approve') ||
            a.can('inv.stock.view'),
      ),
      (
        Icons.shopping_cart_rounded,
        'Purchase requests',
        AppRoutes.inventoryPurchaseRequests,
        a.can('inv.pr.request') ||
            a.can('inv.pr.approve') ||
            a.can('inv.procure.operate'),
      ),
      (
        Icons.receipt_long_rounded,
        'Purchase orders',
        AppRoutes.inventoryPurchaseOrders,
        a.can('inv.procure.operate'),
      ),
      (
        Icons.storefront_rounded,
        'Vendors',
        AppRoutes.inventoryVendors,
        a.can('inv.vendors.manage') || a.can('inv.procure.operate'),
      ),
      (
        Icons.warehouse_rounded,
        'Stores',
        AppRoutes.inventoryStores,
        a.can('inv.stock.view') || a.can('inv.settings'),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : p.errorMessage != null
          ? Center(child: Text(p.errorMessage!))
          : GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final t in tiles.where((t) => t.$4))
                  Card(
                    child: InkWell(
                      onTap: () => context.push(t.$3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(t.$1, size: 36),
                          const SizedBox(height: 8),
                          Text(t.$2),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
