import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/maintenance/maintenance_page.dart';
import 'package:inventory/src/ui/assets/registry/asset_form_page.dart';
import 'package:inventory/src/ui/assets/registry/assets_page.dart';
import 'package:inventory/src/ui/insights/import/import_page.dart';
import 'package:inventory/src/ui/insights/overview/inventory_overview_page.dart';
import 'package:inventory/src/ui/insights/reports/report_page.dart';
import 'package:inventory/src/ui/insights/reports/reports_page.dart';
import 'package:inventory/src/ui/insights/verifications/verification_page.dart';
import 'package:inventory/src/ui/insights/verifications/verifications_page.dart';
import 'package:inventory/src/ui/masters/categories/categories_page.dart';
import 'package:inventory/src/ui/masters/items/item_details_page.dart';
import 'package:inventory/src/ui/masters/items/item_form_page.dart';
import 'package:inventory/src/ui/masters/items/items_page.dart';
import 'package:inventory/src/ui/masters/stores/stores_page.dart';
import 'package:inventory/src/ui/masters/units/units_page.dart';
import 'package:inventory/src/ui/procurement/invoices/invoices_page.dart';
import 'package:inventory/src/ui/procurement/purchase_orders/purchase_order_form_page.dart';
import 'package:inventory/src/ui/procurement/purchase_orders/purchase_order_page.dart';
import 'package:inventory/src/ui/procurement/purchase_orders/purchase_order_receive_page.dart';
import 'package:inventory/src/ui/procurement/purchase_orders/purchase_orders_page.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/purchase_request_form_page.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/purchase_request_page.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/purchase_requests_page.dart';
import 'package:inventory/src/ui/procurement/quotations/quotation_form_page.dart';
import 'package:inventory/src/ui/procurement/quotations/quotations_page.dart';
import 'package:inventory/src/ui/procurement/vendors/vendor_form_page.dart';
import 'package:inventory/src/ui/procurement/vendors/vendor_page.dart';
import 'package:inventory/src/ui/procurement/vendors/vendors_page.dart';
import 'package:inventory/src/ui/routing/inventory_destinations.dart';
import 'package:inventory/src/ui/stock/balance/stock_details_page.dart';
import 'package:inventory/src/ui/stock/balance/stock_page.dart';
import 'package:inventory/src/ui/stock/issues/issue_request_form_page.dart';
import 'package:inventory/src/ui/stock/issues/issue_request_page.dart';
import 'package:inventory/src/ui/stock/issues/issue_requests_page.dart';
import 'package:inventory/src/ui/stock/issues/issue_return_page.dart';
import 'package:inventory/src/ui/stock/receive/receive_page.dart';
import 'package:inventory/src/ui/stock/transfers/transfer_form_page.dart';
import 'package:inventory/src/ui/stock/transfers/transfer_page.dart';
import 'package:inventory/src/ui/stock/transfers/transfers_page.dart';
import 'package:inventory/src/ui/stock/unavailable/unavailable_page.dart';
import 'package:inventory/src/ui/stock/unavailable/unavailable_resolve_page.dart';
import 'package:provider/provider.dart';

/// Inventory screens as go_router routes, inside a shell that adds side navigation on wide screens.
List<RouteBase> inventoryRoutes() => [
  ShellRoute(
    builder: (context, state, child) => IcueModuleShell(
      title: 'Inventory',
      homePath: InventoryRoutes.inventory,
      location: state.uri.path,
      destinations: [
        for (final entry in inventoryEntries(
          context.watch<InventoryProvider>().access,
        ))
          entry.destination,
      ],
      child: child,
    ),
    routes: _inventoryPages,
  ),
];

final _inventoryPages = <RouteBase>[
  GoRoute(
    path: InventoryRoutes.inventory,
    name: InventoryRoutes.inventoryName,
    builder: (context, state) => const InventoryLanding(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryCategories,
    name: InventoryRoutes.inventoryCategoriesName,
    builder: (context, state) => const CategoriesPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryUnits,
    name: InventoryRoutes.inventoryUnitsName,
    builder: (context, state) => const UnitsPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryStores,
    name: InventoryRoutes.inventoryStoresName,
    builder: (context, state) => const StoresPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryItems,
    name: InventoryRoutes.inventoryItemsName,
    builder: (context, state) =>
        ItemsPage(categoryId: state.uri.queryParameters['category']),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryItemForm,
    name: InventoryRoutes.inventoryItemFormName,
    builder: (context, state) =>
        ItemFormPage(item: state.extra as InventoryItem?),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryItemDetails,
    name: InventoryRoutes.inventoryItemDetailsName,
    builder: (context, state) =>
        ItemDetailsPage(itemId: state.uri.queryParameters['id'] ?? ''),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryStock,
    name: InventoryRoutes.inventoryStockName,
    builder: (context, state) => const StockPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryStockDetails,
    name: InventoryRoutes.inventoryStockDetailsName,
    builder: (context, state) =>
        StockDetailsPage(balanceId: state.uri.queryParameters['id'] ?? ''),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryReceive,
    name: InventoryRoutes.inventoryReceiveName,
    builder: (context, state) =>
        ReceivePage(storeId: state.uri.queryParameters['store']),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryRequests,
    name: InventoryRoutes.inventoryRequestsName,
    builder: (context, state) => const IssueRequestsPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryRequestForm,
    name: InventoryRoutes.inventoryRequestFormName,
    builder: (context, state) => const IssueRequestFormPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryRequestDetail,
    name: InventoryRoutes.inventoryRequestDetailName,
    builder: (context, state) =>
        IssueRequestPage(requestId: state.uri.queryParameters['id'] ?? ''),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryIssueReturn,
    name: InventoryRoutes.inventoryIssueReturnName,
    builder: (context, state) =>
        IssueReturnPage(issue: state.extra! as InventoryIssue),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryVendors,
    name: InventoryRoutes.inventoryVendorsName,
    builder: (context, state) => const VendorsPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryVendorDetail,
    name: InventoryRoutes.inventoryVendorDetailName,
    builder: (context, state) =>
        VendorPage(vendorId: state.uri.queryParameters['id'] ?? ''),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryVendorForm,
    name: InventoryRoutes.inventoryVendorFormName,
    builder: (context, state) =>
        VendorFormPage(vendorId: state.uri.queryParameters['id']),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryPurchaseRequests,
    name: InventoryRoutes.inventoryPurchaseRequestsName,
    builder: (context, state) => const PurchaseRequestsPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryPurchaseRequestForm,
    name: InventoryRoutes.inventoryPurchaseRequestFormName,
    builder: (context, state) => PurchaseRequestFormPage(
      existing: state.extra as InventoryPurchaseRequest?,
    ),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryPurchaseRequestDetail,
    name: InventoryRoutes.inventoryPurchaseRequestDetailName,
    builder: (context, state) =>
        PurchaseRequestPage(requestId: state.uri.queryParameters['id'] ?? ''),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryQuotations,
    name: InventoryRoutes.inventoryQuotationsName,
    builder: (context, state) =>
        QuotationsPage(request: state.extra! as InventoryPurchaseRequest),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryQuotationForm,
    name: InventoryRoutes.inventoryQuotationFormName,
    builder: (context, state) {
      final (r, q) =
          state.extra! as (InventoryPurchaseRequest, InventoryQuotation?);
      return QuotationFormPage(request: r, existing: q);
    },
  ),
  GoRoute(
    path: InventoryRoutes.inventoryPurchaseOrders,
    name: InventoryRoutes.inventoryPurchaseOrdersName,
    builder: (context, state) => const PurchaseOrdersPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryPurchaseOrderDetail,
    name: InventoryRoutes.inventoryPurchaseOrderDetailName,
    builder: (context, state) =>
        PurchaseOrderPage(order: state.extra! as InventoryPurchaseOrder),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryPurchaseOrderForm,
    name: InventoryRoutes.inventoryPurchaseOrderFormName,
    builder: (context, state) {
      final (r, q, o) =
          state.extra!
              as (
                InventoryPurchaseRequest,
                InventoryQuotation?,
                InventoryPurchaseOrder?,
              );
      return PurchaseOrderFormPage(request: r, quotation: q, existing: o);
    },
  ),
  GoRoute(
    path: InventoryRoutes.inventoryPoReceive,
    name: InventoryRoutes.inventoryPoReceiveName,
    builder: (context, state) =>
        PurchaseOrderReceivePage(order: state.extra! as InventoryPurchaseOrder),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryAssets,
    name: InventoryRoutes.inventoryAssetsName,
    builder: (context, state) => const AssetsPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryAssetForm,
    name: InventoryRoutes.inventoryAssetFormName,
    builder: (context, state) => const AssetFormPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryMaintenance,
    name: InventoryRoutes.inventoryMaintenanceName,
    builder: (context, state) => const MaintenancePage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryReports,
    name: InventoryRoutes.inventoryReportsName,
    builder: (context, state) => const InventoryReportsPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryReport,
    name: InventoryRoutes.inventoryReportName,
    builder: (context, state) =>
        InventoryReportPage(def: state.extra! as ReportDef),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryImport,
    name: InventoryRoutes.inventoryImportName,
    builder: (context, state) => const ImportPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryVerifications,
    name: InventoryRoutes.inventoryVerificationsName,
    builder: (context, state) => const VerificationsPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryVerification,
    name: InventoryRoutes.inventoryVerificationName,
    builder: (context, state) =>
        VerificationPage(verification: state.extra! as InventoryVerification),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryInvoices,
    name: InventoryRoutes.inventoryInvoicesName,
    builder: (context, state) => const InvoicesPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryTransfers,
    name: InventoryRoutes.inventoryTransfersName,
    builder: (context, state) => const TransfersPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryTransferForm,
    name: InventoryRoutes.inventoryTransferFormName,
    builder: (context, state) => const TransferFormPage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryTransferDetail,
    name: InventoryRoutes.inventoryTransferDetailName,
    builder: (context, state) =>
        StockTransferPage(transferId: state.uri.queryParameters['id'] ?? ''),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryUnavailable,
    name: InventoryRoutes.inventoryUnavailableName,
    builder: (context, state) => const UnavailablePage(),
  ),
  GoRoute(
    path: InventoryRoutes.inventoryUnavailableResolve,
    name: InventoryRoutes.inventoryUnavailableResolveName,
    builder: (context, state) => UnavailableResolvePage(
      unavailableId: state.uri.queryParameters['id'] ?? '',
    ),
  ),
];
