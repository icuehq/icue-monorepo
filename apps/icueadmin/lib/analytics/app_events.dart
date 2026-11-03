import 'package:icue_firebase/icue_firebase.dart';

/// Analytics event names for the admin app. Logged on successful actions only.
abstract final class AppEvents {
  static const login = 'login';
  static const logout = 'logout';
  static const branchSelected = 'branch_selected';
  static const driverAdded = 'driver_added';
  static const driverUpdated = 'driver_updated';
  static const driverDeleted = 'driver_deleted';
  static const vehicleAdded = 'vehicle_added';
  static const vehicleUpdated = 'vehicle_updated';
  static const vehicleDeleted = 'vehicle_deleted';
  static const attendanceSubmitted = 'attendance_submitted';
  static const gatepassIssued = 'gatepass_issued';
  static const gatepassReviewed = 'gatepass_reviewed';
  static const complaintCreated = 'complaint_created';
  static const complaintUpdated = 'complaint_updated';
  static const cleaningLogSubmitted = 'cleaning_log_submitted';
  static const alcoholTestSubmitted = 'alcohol_test_submitted';
  static const expenseSubmitted = 'expense_submitted';
  static const selfFillingStarted = 'self_filling_started';
  static const selfFillingEnded = 'self_filling_ended';
  static const announcementPosted = 'announcement_posted';
  static const vehiclesArrived = 'vehicles_arrived';
  static const vehiclesLeft = 'vehicles_left';
  static const routeTimeUpdated = 'route_time_updated';
}

void track(String event, [Map<String, Object>? parameters]) =>
    AnalyticsService.instance.logEvent(event, parameters: parameters);
