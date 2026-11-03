/// Hive box and key constants.
/// Names match the existing app setup to ensure seamless user updates without data loss.
abstract final class StorageConstants {
  // --- Box Names ---
  static const String userInfoBox = 'userInfo-v2';
  static const String fcmTokenBox = 'fcmToken-v1';
  static const String getActionsByRoleBox = 'getActionsByRole-v2';
  static const String standardsBox = 'standards-v2';
  static const String announcementTitleBox = 'announcementTitle-v2';
  static const String routesBox = 'routes-v2';
  static const String vehicleBox = 'vehicle-v2';
  static const String vehicleDetailsBox = 'vehicleDetails-v2';
  static const String createAttendanceBox = 'createAttendance-v2';
  static const String personTypesBox = 'personTypes-v2';
  static const String fuelPriceBox = 'fuelPriceBox-v2';
  static const String zonalBranchBox = 'zonalBranch-v2';
  static const String expenseTypesBox = 'expenseTypes-v2';
  static const String expenseCategoryBox = 'expenseCategory-v2';
  static const String fuelStorageBox = 'fuelStorage-v2';

  // --- Key Names ---
  static const String fcmTokenKey = 'fcm_token';
  static const String currentUserKey = 'current_user';
}
