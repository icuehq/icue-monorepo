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
  static const String addDriverName = 'addDriver';

  static const String driverInfo = '/drivers/info';
  static const String driverInfoName = 'driverInfo';

  static const String driverDocs = '/drivers/docs';
  static const String driverDocsName = 'driverDocs';

  static const String vehicles = '/vehicles';
  static const String vehiclesName = 'vehicles';

  static const String addVehicle = '/vehicles/add';
  static const String addVehicleName = 'addVehicle';

  static const String vehicleDetails = '/vehicles/details';
  static const String vehicleDetailsName = 'vehicleDetails';

  static const String vehicleDocs = '/vehicles/docs';
  static const String vehicleDocsName = 'vehicleDocs';

  static const String manageRoutes = '/routes';
  static const String manageRoutesName = 'manageRoutes';

  static const String studentRouteChange = '/routes/student-route-change';
  static const String studentRouteChangeName = 'studentRouteChange';

  static const String routeTimeChange = '/routes/route-time-change';
  static const String routeTimeChangeName = 'routeTimeChange';

  static const String announcements = '/announcements';
  static const String announcementsName = 'announcements';

  static const String postAnnouncement = '/announcements/post';
  static const String postAnnouncementName = 'postAnnouncement';

  static const String repairsExpense = '/repairs-expense';
  static const String repairsExpenseName = 'repairsExpense';

  static const String vehicleOptions = '/repairs-expense/options';
  static const String vehicleOptionsName = 'vehicleOptions';

  static const String manageExpense = '/manage-expense';
  static const String manageExpenseName = 'manageExpense';

  static const String addExpense = '/expenses/add';
  static const String addExpenseName = 'addExpense';

  static const String selfFilling = '/expenses/self-filling';
  static const String selfFillingName = 'selfFilling';

  static const String endFilling = '/expenses/end-filling';
  static const String endFillingName = 'endFilling';

  static const String expenseConfirmation = '/expenses/confirmation';
  static const String expenseConfirmationName = 'expenseConfirmation';

  static const String logBook = '/logbook';
  static const String logBookName = 'logBook';

  static const String complaintsDashboard = '/logbook/complaints-dashboard';
  static const String complaintsDashboardName = 'complaintsDashboard';

  static const String complaints = '/logbook/complaints';
  static const String complaintsName = 'complaints';

  static const String complaintDetails = '/logbook/complaints/details';
  static const String complaintDetailsName = 'complaintDetails';

  static const String addComplaint = '/logbook/complaints/add';
  static const String addComplaintName = 'addComplaint';

  static const String cleaningLog = '/logbook/cleaning';
  static const String cleaningLogName = 'cleaningLog';

  static const String alcoholTestForm = '/logbook/alcohol-test';
  static const String alcoholTestFormName = 'alcoholTestForm';

  static const String reports = '/reports';
  static const String reportsName = 'reports';

  static const String arrivalTimeReport = '/reports/arrival-time';
  static const String arrivalTimeReportName = 'arrivalTimeReport';

  static const String cleaningReport = '/reports/cleaning';
  static const String cleaningReportName = 'cleaningReport';

  static const String alcoholTestReport = '/reports/alcohol-test';
  static const String alcoholTestReportName = 'alcoholTestReport';

  static const String fuelReport = '/reports/fuel';
  static const String fuelReportName = 'fuelReport';

  static const String mileageReport = '/reports/mileage';
  static const String mileageReportName = 'mileageReport';

  static const String overSpeedReport = '/reports/over-speed';
  static const String overSpeedReportName = 'overSpeedReport';

  static const String gatePass = '/gatepass';
  static const String gatePassName = 'gatePass';

  static const String generateGatePass = '/gatepass/generate';
  static const String generateGatePassName = 'generateGatePass';

  static const String confirmGatePass = '/gatepass/confirm';
  static const String confirmGatePassName = 'confirmGatePass';

  static const String pendingGatePass = '/gatepass/pending';
  static const String pendingGatePassName = 'pendingGatePass';

  static const String fleetStatus = '/tracking/fleet-status';
  static const String fleetStatusName = 'fleetStatus';

  static const String trackBus = '/tracking/track-bus';
  static const String trackBusName = 'trackBus';

  static const String trackingWebview = '/tracking/webview';
  static const String trackingWebviewName = 'trackingWebview';

  static const String dropBoarding = '/drop-boarding';
  static const String dropBoardingName = 'dropBoarding';

  static const String dropVehicles = '/drop-boarding/drop-vehicles';
  static const String dropVehiclesName = 'dropVehicles';

  static const String boarding = '/drop-boarding/boarding';
  static const String boardingName = 'boarding';

  static const String attendance = '/attendance';
  static const String attendanceName = 'attendance';

  static const String attendanceSections = '/attendance/sections';
  static const String attendanceSectionsName = 'attendanceSections';

  static const String createAttendance = '/attendance/create';
  static const String createAttendanceName = 'createAttendance';

  static const String sdkAttendance = '/attendance/sdk';
  static const String sdkAttendanceName = 'sdkAttendance';

  static const String attendanceConfirmation = '/attendance/confirmation';
  static const String attendanceConfirmationName = 'attendanceConfirmation';
}
