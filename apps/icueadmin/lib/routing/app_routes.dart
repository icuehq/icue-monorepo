abstract final class AppRoutes {
  static const String dashboard = '/';
  static const String dashboardName = 'dashboard';

  static const String login = '/login';
  static const String loginName = 'login';

  static const String branches = '/branches';
  static const String branchesName = 'branches';

  static const String drivers = '/layout.drivers';
  static const String driversName = 'drivers';

  static const String addDriver = '/layout.drivers/add-driver';
  static const String addDriverName = 'addDriver';

  static const String driverInfo = '/layout.drivers/driver-info';
  static const String driverInfoName = 'driverInfo';

  static const String driverDocs = '/layout.drivers/driver-docs';
  static const String driverDocsName = 'driverDocs';

  static const String vehicles = '/layout.vehicles';
  static const String vehiclesName = 'vehicles';

  static const String addVehicle = '/layout.vehicles/add-vehicle';
  static const String addVehicleName = 'addVehicle';

  static const String vehicleDetails = '/layout.vehicles/vehicle-details';
  static const String vehicleDetailsName = 'vehicleDetails';

  static const String vehicleDocs = '/layout.vehicles/vehicle-docs';
  static const String vehicleDocsName = 'vehicleDocs';

  static const String manageRoutes = '/layout.routes';
  static const String manageRoutesName = 'manageRoutes';

  static const String studentRouteChange =
      '/layout.routes/student-route-change';
  static const String studentRouteChangeName = 'studentRouteChange';

  static const String routeTimeChange = '/layout.routes/route-time-change';
  static const String routeTimeChangeName = 'routeTimeChange';

  static const String announcements =
      '/layout.fleetannouncement/layout.annoucements';
  static const String announcementsName = 'announcements';

  static const String postAnnouncement = '/layout.fleetannouncement';
  static const String postAnnouncementName = 'postAnnouncement';

  static const String repairsExpense = '/layout.repairsandexpenses';
  static const String repairsExpenseName = 'repairsExpense';

  static const String vehicleOptions = '/layout.repairsandexpenses/options';
  static const String vehicleOptionsName = 'vehicleOptions';

  static const String manageExpense = '/layout.fuelfilling';
  static const String manageExpenseName = 'manageExpense';

  static const String addExpense = '/layout.fuelfilling/add';
  static const String addExpenseName = 'addExpense';

  static const String selfFilling = '/layout.fuelfilling/self-filling';
  static const String selfFillingName = 'selfFilling';

  static const String endFilling = '/layout.fuelfilling/end-filling';
  static const String endFillingName = 'endFilling';

  static const String expenseConfirmation = '/layout.fuelfilling/confirmation';
  static const String expenseConfirmationName = 'expenseConfirmation';

  static const String logBook = '/layout.logbook';
  static const String logBookName = 'logBook';

  static const String complaintsDashboard =
      '/layout.logbook/layout.complaintsdashboard';
  static const String complaintsDashboardName = 'complaintsDashboard';

  static const String complaints = '/layout.logbook/layout.complaints';
  static const String complaintsName = 'complaints';

  static const String complaintDetails =
      '/layout.logbook/layout.complaints/details';
  static const String complaintDetailsName = 'complaintDetails';

  static const String addComplaint =
      '/layout.logbook/layout.complaints/add-complaint';
  static const String addComplaintName = 'addComplaint';

  static const String cleaningLog = '/layout.logbook/layout.cleaninglog';
  static const String cleaningLogName = 'cleaningLog';

  static const String alcoholTestForm = '/layout.logbook/layout.alcoholtest';
  static const String alcoholTestFormName = 'alcoholTestForm';

  static const String reports = '/layout.reports';
  static const String reportsName = 'reports';

  static const String arrivalTimeReport =
      '/layout.reports/layout.vehiclearrival';
  static const String arrivalTimeReportName = 'arrivalTimeReport';

  static const String cleaningReport = '/layout.reports/layout.vehiclecleaning';
  static const String cleaningReportName = 'cleaningReport';

  static const String alcoholTestReport =
      '/layout.reports/layout.alcoholtestreport';
  static const String alcoholTestReportName = 'alcoholTestReport';

  static const String fuelReport = '/layout.reports/fuel';
  static const String fuelReportName = 'fuelReport';

  static const String mileageReport = '/layout.reports/mileage';
  static const String mileageReportName = 'mileageReport';

  static const String overSpeedReport = '/layout.reports/over-speed';
  static const String overSpeedReportName = 'overSpeedReport';

  static const String gatePass = '/layout.gatepass';
  static const String gatePassName = 'gatePass';

  static const String generateGatePass =
      '/layout.gatepass/layout.generategatepass';
  static const String generateGatePassName = 'generateGatePass';

  static const String confirmGatePass = '/layout.gatepass/confirm';
  static const String confirmGatePassName = 'confirmGatePass';

  static const String pendingGatePass =
      '/layout.gatepass/layout.approvegatepass';
  static const String pendingGatePassName = 'pendingGatePass';

  static const String fleetStatus = '/layout.fleetdashboard';
  static const String fleetStatusName = 'fleetStatus';

  static const String trackBus = '/layout.trackvehicle';
  static const String trackBusName = 'trackBus';

  static const String trackingWebview = '/layout.trackvehicle/webview';
  static const String trackingWebviewName = 'trackingWebview';

  static const String dropBoarding = '/layout.dropboarding';
  static const String dropBoardingName = 'dropBoarding';

  static const String dropVehicles = '/layout.dropboarding/drop-vehicles';
  static const String dropVehiclesName = 'dropVehicles';

  static const String boarding = '/layout.dropboarding/boarding';
  static const String boardingName = 'boarding';

  static const String attendance = '/layout.attendance';
  static const String attendanceName = 'attendance';

  static const String attendanceSections = '/layout.attendance/sections';
  static const String attendanceSectionsName = 'attendanceSections';

  static const String createAttendance = '/layout.attendance/create';
  static const String createAttendanceName = 'createAttendance';

  static const String sdkAttendance = '/layout.attendance/sdk';
  static const String sdkAttendanceName = 'sdkAttendance';

  static const String attendanceConfirmation =
      '/layout.attendance/confirmation';
  static const String attendanceConfirmationName = 'attendanceConfirmation';

  static const String inventory = '/layout.inventory';
  static const String inventoryName = 'inventory';

  static const String inventoryCategories = '/layout.inventory/categories';
  static const String inventoryCategoriesName = 'inventoryCategories';

  static const String inventoryUnits = '/layout.inventory/units';
  static const String inventoryUnitsName = 'inventoryUnits';

  static const String inventoryStores = '/layout.inventory/stores';
  static const String inventoryStoresName = 'inventoryStores';

  static const String inventoryItems = '/layout.inventory/items';
  static const String inventoryItemsName = 'inventoryItems';

  static const String inventoryItemForm = '/layout.inventory/items/form';
  static const String inventoryItemFormName = 'inventoryItemForm';

  static const String inventoryItemDetails = '/layout.inventory/items/details';
  static const String inventoryItemDetailsName = 'inventoryItemDetails';

  static const String inventoryStock = '/layout.inventory/stock';
  static const String inventoryStockName = 'inventoryStock';

  static const String inventoryReceive = '/layout.inventory/stock/receive';
  static const String inventoryReceiveName = 'inventoryReceive';

  static const String inventoryRequests = '/layout.inventory/requests';
  static const String inventoryRequestsName = 'inventoryRequests';

  static const String inventoryRequestForm = '/layout.inventory/requests/new';
  static const String inventoryRequestFormName = 'inventoryRequestForm';

  static const String inventoryTransfers = '/layout.inventory/transfers';
  static const String inventoryTransfersName = 'inventoryTransfers';

  static const String inventoryTransferForm = '/layout.inventory/transfers/new';
  static const String inventoryTransferFormName = 'inventoryTransferForm';

  static const String inventoryDashboard = '/layout.inventory/dashboard';
  static const String inventoryDashboardName = 'inventoryDashboard';

  static const String inventoryReports = '/layout.inventory/reports';
  static const String inventoryReportsName = 'inventoryReports';

  static const String inventoryReport = '/layout.inventory/reports/view';
  static const String inventoryReportName = 'inventoryReport';

  static const String inventoryVerifications =
      '/layout.inventory/verifications';
  static const String inventoryVerificationsName = 'inventoryVerifications';

  static const String inventoryVerification =
      '/layout.inventory/verifications/view';
  static const String inventoryVerificationName = 'inventoryVerification';

  static const String inventoryUnavailable = '/layout.inventory/unavailable';
  static const String inventoryUnavailableName = 'inventoryUnavailable';

  static const String inventoryVendors = '/layout.inventory/vendors';
  static const String inventoryVendorsName = 'inventoryVendors';

  static const String inventoryPurchaseRequests =
      '/layout.inventory/purchase-requests';
  static const String inventoryPurchaseRequestsName =
      'inventoryPurchaseRequests';

  static const String inventoryPurchaseRequestForm =
      '/layout.inventory/purchase-requests/form';
  static const String inventoryPurchaseRequestFormName =
      'inventoryPurchaseRequestForm';

  static const String inventoryQuotations = '/layout.inventory/quotations';
  static const String inventoryQuotationsName = 'inventoryQuotations';

  static const String inventoryQuotationForm =
      '/layout.inventory/quotations/form';
  static const String inventoryQuotationFormName = 'inventoryQuotationForm';

  static const String inventoryPurchaseOrders =
      '/layout.inventory/purchase-orders';
  static const String inventoryPurchaseOrdersName = 'inventoryPurchaseOrders';

  static const String inventoryPurchaseOrderForm =
      '/layout.inventory/purchase-orders/form';
  static const String inventoryPurchaseOrderFormName =
      'inventoryPurchaseOrderForm';

  static const String inventoryPoReceive =
      '/layout.inventory/purchase-orders/receive';
  static const String inventoryPoReceiveName = 'inventoryPoReceive';

  static const String inventoryInvoices = '/layout.inventory/invoices';
  static const String inventoryInvoicesName = 'inventoryInvoices';

  static const String inventoryImport = '/layout.inventory/import';
  static const String inventoryImportName = 'inventoryImport';
  static const String inventoryAssets = '/layout.inventory/assets';
  static const String inventoryAssetsName = 'inventoryAssets';

  static const String inventoryAssetForm = '/layout.inventory/assets/form';
  static const String inventoryAssetFormName = 'inventoryAssetForm';

  static const String inventoryMaintenance = '/layout.inventory/maintenance';
  static const String inventoryMaintenanceName = 'inventoryMaintenance';

  static const String library = '/layout.library';
  static const String libraryName = 'library';

  static const String libraryList = '/layout.library/libraries';
  static const String libraryListName = 'libraryList';

  static const String libraryCategories = '/layout.library/categories';
  static const String libraryCategoriesName = 'libraryCategories';

  static const String libraryCatalogue = '/layout.library/catalogue';
  static const String libraryCatalogueName = 'libraryCatalogue';

  static const String libraryBookForm = '/layout.library/catalogue/form';
  static const String libraryBookFormName = 'libraryBookForm';

  static const String libraryCopies = '/layout.library/copies';
  static const String libraryCopiesName = 'libraryCopies';

  static const String libraryBookDetails = '/layout.library/catalogue/details';
  static const String libraryBookDetailsName = 'libraryBookDetails';

  static const String libraryMembers = '/layout.library/members';
  static const String libraryMembersName = 'libraryMembers';

  static const String libraryPolicies = '/layout.library/policies';
  static const String libraryPoliciesName = 'libraryPolicies';

  static const String libraryCirculation = '/layout.library/circulation';
  static const String libraryCirculationName = 'libraryCirculation';

  static const String libraryReservations = '/layout.library/reservations';
  static const String libraryReservationsName = 'libraryReservations';

  static const String libraryFines = '/layout.library/fines';
  static const String libraryFinesName = 'libraryFines';

  static const String libraryIncidents = '/layout.library/incidents';
  static const String libraryIncidentsName = 'libraryIncidents';
  static const String libraryTransfers = '/layout.library/transfers';
  static const String libraryTransfersName = 'libraryTransfers';
  static const String libraryVerification = '/layout.library/verification';
  static const String libraryVerificationName = 'libraryVerification';
  static const String libraryDashboard = '/layout.library/dashboard';
  static const String libraryDashboardName = 'libraryDashboard';
  static const String libraryReports = '/layout.library/reports';
  static const String libraryReportsName = 'libraryReports';
  static const String libraryReport = '/layout.library/reports/view';
  static const String libraryReportName = 'libraryReport';
  static const String libraryImport = '/layout.library/import';
  static const String libraryImportName = 'libraryImport';
}
