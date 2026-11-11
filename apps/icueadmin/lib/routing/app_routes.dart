/// Route paths are `/<module>[/<sub-page>]` in kebab-case; names are the path
/// with `/` replaced by `.`. Backend `layout.*` ids are mapped to these paths
/// in the dashboard, never used as paths.
abstract final class AppRoutes {
  static const String dashboard = '/';
  static const String dashboardName = 'dashboard';

  static const String login = '/login';
  static const String loginName = 'login';

  static const String branches = '/branches';
  static const String branchesName = 'branches';

  static const String drivers = '/drivers';
  static const String driversName = 'drivers';

  static const String addDriver = '/drivers/add';
  static const String addDriverName = 'drivers.add';

  static const String driverInfo = '/drivers/info';
  static const String driverInfoName = 'drivers.info';

  static const String driverDocs = '/drivers/docs';
  static const String driverDocsName = 'drivers.docs';

  static const String vehicles = '/vehicles';
  static const String vehiclesName = 'vehicles';

  static const String addVehicle = '/vehicles/add';
  static const String addVehicleName = 'vehicles.add';

  static const String vehicleDetails = '/vehicles/details';
  static const String vehicleDetailsName = 'vehicles.details';

  static const String vehicleDocs = '/vehicles/docs';
  static const String vehicleDocsName = 'vehicles.docs';

  static const String manageRoutes = '/routes';
  static const String manageRoutesName = 'routes';

  static const String studentRouteChange = '/routes/student-change';
  static const String studentRouteChangeName = 'routes.student-change';

  static const String routeTimeChange = '/routes/time-change';
  static const String routeTimeChangeName = 'routes.time-change';

  static const String postAnnouncement = '/announcements';
  static const String postAnnouncementName = 'announcements';

  static const String announcements = '/announcements/history';
  static const String announcementsName = 'announcements.history';

  static const String repairsExpense = '/repairs-expenses';
  static const String repairsExpenseName = 'repairs-expenses';

  static const String vehicleOptions = '/repairs-expenses/options';
  static const String vehicleOptionsName = 'repairs-expenses.options';

  static const String addExpense = '/repairs-expenses/add';
  static const String addExpenseName = 'repairs-expenses.add';

  static const String manageExpense = '/fuel-filling';
  static const String manageExpenseName = 'fuel-filling';

  static const String selfFilling = '/fuel-filling/self-filling';
  static const String selfFillingName = 'fuel-filling.self-filling';

  static const String selfFillingVehicles =
      '/fuel-filling/self-filling/vehicles';
  static const String selfFillingVehiclesName =
      'fuel-filling.self-filling.vehicles';

  static const String looseFuel = '/fuel-filling/loose-fuel';
  static const String looseFuelName = 'fuel-filling.loose-fuel';

  static const String endFilling = '/fuel-filling/end-filling';
  static const String endFillingName = 'fuel-filling.end-filling';

  static const String expenseConfirmation = '/fuel-filling/confirmation';
  static const String expenseConfirmationName = 'fuel-filling.confirmation';

  static const String logBook = '/logbook';
  static const String logBookName = 'logbook';

  static const String complaintsDashboard = '/logbook/complaints-dashboard';
  static const String complaintsDashboardName = 'logbook.complaints-dashboard';

  static const String complaints = '/logbook/complaints';
  static const String complaintsName = 'logbook.complaints';

  static const String complaintDetails = '/logbook/complaints/details';
  static const String complaintDetailsName = 'logbook.complaints.details';

  static const String addComplaint = '/logbook/complaints/add';
  static const String addComplaintName = 'logbook.complaints.add';

  static const String cleaningLog = '/logbook/cleaning-log';
  static const String cleaningLogName = 'logbook.cleaning-log';

  static const String alcoholTestForm = '/logbook/alcohol-test';
  static const String alcoholTestFormName = 'logbook.alcohol-test';

  static const String reports = '/reports';
  static const String reportsName = 'reports';

  static const String arrivalTimeReport = '/reports/vehicle-arrival';
  static const String arrivalTimeReportName = 'reports.vehicle-arrival';

  static const String cleaningReport = '/reports/vehicle-cleaning';
  static const String cleaningReportName = 'reports.vehicle-cleaning';

  static const String alcoholTestReport = '/reports/alcohol-test';
  static const String alcoholTestReportName = 'reports.alcohol-test';

  static const String fuelReport = '/reports/fuel';
  static const String fuelReportName = 'reports.fuel';

  static const String mileageReport = '/reports/mileage';
  static const String mileageReportName = 'reports.mileage';

  static const String overSpeedReport = '/reports/over-speed';
  static const String overSpeedReportName = 'reports.over-speed';

  static const String gatePass = '/gate-pass';
  static const String gatePassName = 'gate-pass';

  static const String generateGatePass = '/gate-pass/generate';
  static const String generateGatePassName = 'gate-pass.generate';

  static const String confirmGatePass = '/gate-pass/confirm';
  static const String confirmGatePassName = 'gate-pass.confirm';

  static const String pendingGatePass = '/gate-pass/pending';
  static const String pendingGatePassName = 'gate-pass.pending';

  static const String fleetStatus = '/fleet-status';
  static const String fleetStatusName = 'fleet-status';

  static const String trackBus = '/track-vehicle';
  static const String trackBusName = 'track-vehicle';

  static const String trackingWebview = '/track-vehicle/webview';
  static const String trackingWebviewName = 'track-vehicle.webview';

  static const String dropBoarding = '/drop-boarding';
  static const String dropBoardingName = 'drop-boarding';

  static const String dropVehicles = '/drop-boarding/drop-vehicles';
  static const String dropVehiclesName = 'drop-boarding.drop-vehicles';

  static const String boarding = '/drop-boarding/boarding';
  static const String boardingName = 'drop-boarding.boarding';

  static const String attendance = '/attendance';
  static const String attendanceName = 'attendance';

  static const String attendanceSections = '/attendance/sections';
  static const String attendanceSectionsName = 'attendance.sections';

  static const String createAttendance = '/attendance/create';
  static const String createAttendanceName = 'attendance.create';

  static const String sdkAttendance = '/attendance/sdk';
  static const String sdkAttendanceName = 'attendance.sdk';

  static const String attendanceConfirmation = '/attendance/confirmation';
  static const String attendanceConfirmationName = 'attendance.confirmation';
}
