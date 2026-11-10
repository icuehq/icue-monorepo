import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/ui/routing/inventory_routes.dart';

/// An Inventory screen reachable from the home grid and the side navigation.
class InventoryEntry {
  const InventoryEntry({
    required this.label,
    required this.path,
    required this.iconAsset,
    required this.group,
  });

  final String label;
  final String path;
  final String iconAsset;
  final String group;

  IcueModuleDestination get destination => IcueModuleDestination(
    label: label,
    path: path,
    iconAsset: iconAsset,
    group: group,
  );
}

/// The Inventory screens [access] may open, in navigation order.
List<InventoryEntry> inventoryEntries(ModuleAccess access) => [
  const InventoryEntry(
    label: 'Overview',
    path: InventoryRoutes.inventory,
    iconAsset: 'assets/dashboard/inventory.png',
    group: 'Overview',
  ),
  if (access.can('inventory.reports.view'))
    const InventoryEntry(
      label: 'Reports',
      path: InventoryRoutes.inventoryReports,
      iconAsset: 'assets/dashboard/reports.png',
      group: 'Overview',
    ),
  if (access.can('inventory.settings') ||
      access.can('inventory.items.manage') ||
      access.can('inventory.vendors.manage'))
    const InventoryEntry(
      label: 'Import',
      path: InventoryRoutes.inventoryImport,
      iconAsset: 'assets/dashboard/inventory-import.png',
      group: 'Overview',
    ),
  if (access.can('inventory.stock.view'))
    const InventoryEntry(
      label: 'Stock',
      path: InventoryRoutes.inventoryStock,
      iconAsset: 'assets/dashboard/inventory-stock.png',
      group: 'Stock',
    ),
  if (access.can('inventory.issue.request') ||
      access.can('inventory.issue.approve') ||
      access.can('inventory.stock.view'))
    const InventoryEntry(
      label: 'Issue requests',
      path: InventoryRoutes.inventoryRequests,
      iconAsset: 'assets/dashboard/inventory-issue-requests.png',
      group: 'Stock',
    ),
  if (access.can('inventory.stock.view'))
    const InventoryEntry(
      label: 'Damaged / expired',
      path: InventoryRoutes.inventoryUnavailable,
      iconAsset: 'assets/dashboard/inventory-stock-verification.png',
      group: 'Stock',
    ),
  if (access.can('inventory.stock.view'))
    const InventoryEntry(
      label: 'Stock verification',
      path: InventoryRoutes.inventoryVerifications,
      iconAsset: 'assets/dashboard/inventory-stock-verification.png',
      group: 'Stock',
    ),
  if (access.can('inventory.stock.view') || access.can('inventory.settings'))
    const InventoryEntry(
      label: 'Stores',
      path: InventoryRoutes.inventoryStores,
      iconAsset: 'assets/dashboard/inventory-stores.png',
      group: 'Stock',
    ),
  if (access.can('inventory.purchaseRequest.request') ||
      access.can('inventory.purchaseRequest.approve') ||
      access.can('inventory.procure.operate'))
    const InventoryEntry(
      label: 'Purchase requests',
      path: InventoryRoutes.inventoryPurchaseRequests,
      iconAsset: 'assets/dashboard/inventory-purchase-requests.png',
      group: 'Procurement',
    ),
  if (access.can('inventory.procure.operate') ||
      access.can('inventory.stock.operate'))
    const InventoryEntry(
      label: 'Purchase orders',
      path: InventoryRoutes.inventoryPurchaseOrders,
      iconAsset: 'assets/dashboard/inventory-purchase-orders.png',
      group: 'Procurement',
    ),
  if (access.can('inventory.procure.operate'))
    const InventoryEntry(
      label: 'Vendor invoices',
      path: InventoryRoutes.inventoryInvoices,
      iconAsset: 'assets/dashboard/inventory-invoices.png',
      group: 'Procurement',
    ),
  if (access.can('inventory.vendors.manage') ||
      access.can('inventory.procure.operate'))
    const InventoryEntry(
      label: 'Vendors',
      path: InventoryRoutes.inventoryVendors,
      iconAsset: 'assets/dashboard/inventory-vendors.png',
      group: 'Procurement',
    ),
  if (access.can('inventory.items.view'))
    const InventoryEntry(
      label: 'Items',
      path: InventoryRoutes.inventoryItems,
      iconAsset: 'assets/dashboard/inventory-items.png',
      group: 'Catalogue',
    ),
  if (access.can('inventory.items.view'))
    const InventoryEntry(
      label: 'Categories',
      path: InventoryRoutes.inventoryCategories,
      iconAsset: 'assets/dashboard/inventory-categories.png',
      group: 'Catalogue',
    ),
  if (access.can('inventory.items.view'))
    const InventoryEntry(
      label: 'Units',
      path: InventoryRoutes.inventoryUnits,
      iconAsset: 'assets/dashboard/inventory-units.png',
      group: 'Catalogue',
    ),
  if (access.can('inventory.assets.view') ||
      access.can('inventory.assets.manage'))
    const InventoryEntry(
      label: 'Assets',
      path: InventoryRoutes.inventoryAssets,
      iconAsset: 'assets/dashboard/inventory-assets.png',
      group: 'Catalogue',
    ),
];
