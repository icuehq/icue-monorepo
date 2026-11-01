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
    final tiles = <(String, String, String, bool)>[
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
        a.can('inv.procure.operate'),
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
    final color = Theme.of(context).primaryColorDark;
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : p.errorMessage != null
          ? Center(child: Text(p.errorMessage!))
          : GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.3,
              children: [
                for (final t in tiles.where((t) => t.$4))
                  Card(
                    elevation: 1,
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () => context.push(t.$3),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(t.$1, width: 56, height: 56),
                            const SizedBox(height: 12),
                            Text(
                              t.$2,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
