/// Route paths and names owned by the inventory feature.
class InventoryRoutes {
  const InventoryRoutes._();

  static const String inventory = '/inventory';
  static const String inventoryName = 'inventory';

  static const String inventoryCategories = '/inventory/categories';
  static const String inventoryCategoriesName = 'inventory.categories';

  static const String inventoryUnits = '/inventory/units';
  static const String inventoryUnitsName = 'inventory.units';

  static const String inventoryStores = '/inventory/stores';
  static const String inventoryStoresName = 'inventory.stores';

  static const String inventoryItems = '/inventory/items';
  static const String inventoryItemsName = 'inventory.items';

  static const String inventoryItemForm = '/inventory/items/form';
  static const String inventoryItemFormName = 'inventory.items.form';

  static const String inventoryItemDetails = '/inventory/items/details';
  static const String inventoryItemDetailsName = 'inventory.items.details';

  static const String inventoryStock = '/inventory/stock';
  static const String inventoryStockName = 'inventory.stock';
  static const String inventoryStockDetails = '/inventory/stock/details';
  static const String inventoryStockDetailsName = 'inventory.stock.details';

  static const String inventoryReceive = '/inventory/stock/receive';
  static const String inventoryReceiveName = 'inventory.stock.receive';

  static const String inventoryRequests = '/inventory/requests';
  static const String inventoryRequestsName = 'inventory.requests';

  static const String inventoryRequestDetail = '/inventory/requests/detail';
  static const String inventoryRequestDetailName = 'inventory.requests.detail';

  static const String inventoryIssueReturn = '/inventory/requests/return';
  static const String inventoryIssueReturnName = 'inventory.requests.return';

  static const String inventoryReports = '/inventory/reports';
  static const String inventoryReportsName = 'inventory.reports';

  static const String inventoryReport = '/inventory/reports/view';
  static const String inventoryReportName = 'inventory.reports.view';

  static const String inventoryUnavailable = '/inventory/unavailable';
  static const String inventoryUnavailableName = 'inventory.unavailable';

  static const String inventoryUnavailableResolve =
      '/inventory/unavailable/resolve';
  static const String inventoryUnavailableResolveName =
      'inventory.unavailable.resolve';

  static const String inventoryPurchaseRequests =
      '/inventory/purchase-requests';
  static const String inventoryPurchaseRequestsName =
      'inventory.purchase-requests';

  static const String inventoryPurchaseRequestForm =
      '/inventory/purchase-requests/form';
  static const String inventoryPurchaseRequestFormName =
      'inventory.purchase-requests.form';

  static const String inventoryPurchaseRequestDetail =
      '/inventory/purchase-requests/detail';
  static const String inventoryPurchaseRequestDetailName =
      'inventory.purchase-requests.detail';

  static const String inventoryAssets = '/inventory/assets';
  static const String inventoryAssetsName = 'inventory.assets';

  static const String inventoryAssetDetails = '/inventory/assets/details';
  static const String inventoryAssetDetailsName = 'inventory.assets.details';

  static const String inventoryAssetForm = '/inventory/assets/form';
  static const String inventoryAssetFormName = 'inventory.assets.form';

  static const String inventoryMaintenance = '/inventory/maintenance';
  static const String inventoryMaintenanceName = 'inventory.maintenance';
}
