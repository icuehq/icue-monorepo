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

  static const String vehicleOptions =
      '/layout.repairsandexpenses/options';
  static const String vehicleOptionsName = 'vehicleOptions';

  static const String manageExpense = '/layout.fuelfilling';
  static const String manageExpenseName = 'manageExpense';

  static const String addExpense = '/layout.fuelfilling/add';
  static const String addExpenseName = 'addExpense';

  static const String selfFilling = '/layout.fuelfilling/self-filling';
  static const String selfFillingName = 'selfFilling';

  static const String endFilling = '/layout.fuelfilling/end-filling';
  static const String endFillingName = 'endFilling';

  static const String expenseConfirmation =
      '/layout.fuelfilling/confirmation';
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

  static const String alcoholTestForm =
      '/layout.logbook/layout.alcoholtest';
  static const String alcoholTestFormName = 'alcoholTestForm';

  static const String reports = '/layout.reports';
  static const String reportsName = 'reports';

  static const String arrivalTimeReport =
      '/layout.reports/layout.vehiclearrival';
  static const String arrivalTimeReportName = 'arrivalTimeReport';

  static const String cleaningReport =
      '/layout.reports/layout.vehiclecleaning';
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

  static const String trackingWebview =
      '/layout.trackvehicle/webview';
  static const String trackingWebviewName = 'trackingWebview';

  static const String dropBoarding = '/layout.dropboarding';
  static const String dropBoardingName = 'dropBoarding';

  static const String dropVehicles =
      '/layout.dropboarding/drop-vehicles';
  static const String dropVehiclesName = 'dropVehicles';

  static const String boarding = '/layout.dropboarding/boarding';
  static const String boardingName = 'boarding';

  static const String attendance = '/layout.attendance';
  static const String attendanceName = 'attendance';

  static const String attendanceSections =
      '/layout.attendance/sections';
  static const String attendanceSectionsName = 'attendanceSections';

  static const String createAttendance =
      '/layout.attendance/create';
  static const String createAttendanceName = 'createAttendance';

  static const String sdkAttendance = '/layout.attendance/sdk';
  static const String sdkAttendanceName = 'sdkAttendance';

  static const String attendanceConfirmation =
      '/layout.attendance/confirmation';
  static const String attendanceConfirmationName = 'attendanceConfirmation';
}
