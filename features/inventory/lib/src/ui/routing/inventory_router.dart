import 'package:auth/auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/routing/inventory_destinations.dart';
import 'package:inventory/src/ui/routing/inventory_pages.dart'
    deferred as pages;
import 'package:inventory/src/ui/widgets/no_store_assigned_gate.dart';
import 'package:inventory/src/ui/widgets/store_manager_logout_button.dart';
import 'package:provider/provider.dart';

Widget _inventoryPage(WidgetBuilder builder) =>
    IcueDeferred(load: pages.loadLibrary, builder: builder);

/// Inventory screens as go_router routes, inside a shell that adds side navigation on wide screens.
List<RouteBase> inventoryRoutes() => [
  ShellRoute(
    builder: (context, state, child) {
      final storeManager = context.read<AuthProvider>().isAssignedStoresOnly;
      return NoStoreAssignedGate(
        child: IcueModuleShell(
          title: 'Inventory',
          homePath: InventoryRoutes.inventory,
          // Store managers live in this module; there is no dashboard to go back to.
          exitPath: storeManager ? null : '/',
          location: state.uri.path,
          footer: const StoreManagerLogoutButton(expanded: true),
          destinations: [
            for (final entry in inventoryEntries()) entry.destination,
          ],
          child: child,
        ),
      );
    },
    routes: _inventoryPages,
  ),
];

final _inventoryPages = <RouteBase>[
  GoRoute(
    path: InventoryRoutes.inventory,
    name: InventoryRoutes.inventoryName,
    builder: (context, state) =>
        _inventoryPage((_) => pages.InventoryLanding()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryCategories,
    name: InventoryRoutes.inventoryCategoriesName,
    builder: (context, state) => _inventoryPage((_) => pages.CategoriesPage()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryUnits,
    name: InventoryRoutes.inventoryUnitsName,
    builder: (context, state) => _inventoryPage((_) => pages.UnitsPage()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryStores,
    name: InventoryRoutes.inventoryStoresName,
    builder: (context, state) => _inventoryPage((_) => pages.StoresPage()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryItems,
    name: InventoryRoutes.inventoryItemsName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.ItemsPage(categoryId: state.uri.queryParameters['category']),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryItemForm,
    name: InventoryRoutes.inventoryItemFormName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.ItemFormPage(item: state.extra as InventoryItem?),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryItemDetails,
    name: InventoryRoutes.inventoryItemDetailsName,
    builder: (context, state) => _inventoryPage(
      (_) =>
          pages.ItemDetailsPage(itemId: state.uri.queryParameters['id'] ?? ''),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryStock,
    name: InventoryRoutes.inventoryStockName,
    builder: (context, state) => _inventoryPage((_) => pages.StockPage()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryStockDetails,
    name: InventoryRoutes.inventoryStockDetailsName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.StockDetailsPage(
        balanceId: state.uri.queryParameters['id'] ?? '',
      ),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryReceive,
    name: InventoryRoutes.inventoryReceiveName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.ReceivePage(storeId: state.uri.queryParameters['store']),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryRequests,
    name: InventoryRoutes.inventoryRequestsName,
    builder: (context, state) =>
        _inventoryPage((_) => pages.IssueRequestsPage()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryRequestDetail,
    name: InventoryRoutes.inventoryRequestDetailName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.IssueRequestPage(
        requestId: state.uri.queryParameters['id'] ?? '',
      ),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryIssueReturn,
    name: InventoryRoutes.inventoryIssueReturnName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.IssueReturnPage(issue: state.extra! as InventoryIssue),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryPurchaseRequests,
    name: InventoryRoutes.inventoryPurchaseRequestsName,
    builder: (context, state) =>
        _inventoryPage((_) => pages.PurchaseRequestsPage()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryPurchaseRequestForm,
    name: InventoryRoutes.inventoryPurchaseRequestFormName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.PurchaseRequestFormPage(
        existing: state.extra as InventoryPurchaseRequest?,
      ),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryPurchaseRequestDetail,
    name: InventoryRoutes.inventoryPurchaseRequestDetailName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.PurchaseRequestPage(
        requestId: state.uri.queryParameters['id'] ?? '',
      ),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryAssets,
    name: InventoryRoutes.inventoryAssetsName,
    builder: (context, state) => _inventoryPage((_) => pages.AssetsPage()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryAssetDetails,
    name: InventoryRoutes.inventoryAssetDetailsName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.AssetDetailsPage(
        assetId: state.uri.queryParameters['id'] ?? '',
      ),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryAssetForm,
    name: InventoryRoutes.inventoryAssetFormName,
    builder: (context, state) => _inventoryPage(
      (_) =>
          pages.AssetFormPage(assetId: state.uri.queryParameters['id'] ?? ''),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryMaintenance,
    name: InventoryRoutes.inventoryMaintenanceName,
    builder: (context, state) => _inventoryPage((_) => pages.MaintenancePage()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryReports,
    name: InventoryRoutes.inventoryReportsName,
    builder: (context, state) =>
        _inventoryPage((_) => pages.InventoryReportsPage()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryReport,
    name: InventoryRoutes.inventoryReportName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.InventoryReportPage(def: state.extra! as ReportDef),
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryUnavailable,
    name: InventoryRoutes.inventoryUnavailableName,
    builder: (context, state) => _inventoryPage((_) => pages.UnavailablePage()),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryUnavailableResolve,
    name: InventoryRoutes.inventoryUnavailableResolveName,
    builder: (context, state) => _inventoryPage(
      (_) => pages.UnavailableResolvePage(
        unavailableId: state.uri.queryParameters['id'] ?? '',
      ),
    ),
  ),
];
