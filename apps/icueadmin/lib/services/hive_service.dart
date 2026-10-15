import 'package:hive_flutter/hive_flutter.dart';

import '../models/announcement_titles.dart';
import '../models/branches.dart';
import '../models/create_attendance.dart';
import '../models/expense_type.dart';
import '../models/fuel_storage.dart';
import '../models/person_types.dart';
import '../models/role_actions.dart';
import '../models/routes.dart';
import '../models/standards.dart';
import '../models/user_info.dart';
import '../models/vehicle.dart';

class HiveService {
  static Box<RoleActions> get getActionsByRoleBox =>
      Hive.box<RoleActions>('getActionsByRole-v2');

  static Box<UserInfo> get userInfoBox => Hive.box<UserInfo>('userInfo-v2');

  static Box<Standards> get standardsBox => Hive.box<Standards>('standards-v2');

  static Box<AnnouncementTitle> get announcementTitleBox =>
      Hive.box<AnnouncementTitle>('announcementTitle-v2');

  static Box<List<Routee>> get routeBox => Hive.box<List<Routee>>('routes-v2');

  static Box<CreateAttendance> get createAttendanceBox =>
      Hive.box<CreateAttendance>('createAttendance-v2');

  static Box<Vehicle> get vehicleBox => Hive.box<Vehicle>('vehicle-v2');

  static Box<VehicleDetails> get vehicleDetailsBox =>
      Hive.box<VehicleDetails>('vehicleDetails-v2');

  static Box<PersonType> get personTypesBox =>
      Hive.box<PersonType>('personTypes-v2');

  static Box<String> get fuelPriceBox => Hive.box<String>('fuelPriceBox-v2');
  static Box<Branch> get zonalBranch => Hive.box<Branch>('zonalBranch-v2');

  static UserInfo? get currentUser {
    if (Hive.isBoxOpen('userInfo-v2') && userInfoBox.values.isNotEmpty) {
      return userInfoBox.values.firstOrNull;
    }
    return null;
  }

  static Branch? get currentZonalBranch {
    if (Hive.isBoxOpen('zonalBranch-v2')) {
      return zonalBranch.get('selected');
    }
    return null;
  }

  static Box<ExpenseType> get expenseTypesBox =>
      Hive.box<ExpenseType>('expenseTypes-v2');

  static Box<Detail> get expenseCategorysBox =>
      Hive.box<Detail>('expenseCategory-v2');

  // static Box<List<Detail>> get expenseSubCategorysBox =>
  //     Hive.box<List<Detail>>('expenseSubCategory-v2');

  static Box<StorageItem> get fuelStorageBox =>
      Hive.box<StorageItem>('fuelStorage-v2');

  static Box<String> get fcmTokenBox => Hive.box<String>('fcmToken-v1');

  static Future<void> initialize() async {
    await Hive.initFlutter();

    Hive.registerAdapter(RoleActionsAdapter());
    Hive.registerAdapter(UserInfoAdapter());
    Hive.registerAdapter(UserClassAdapter());
    Hive.registerAdapter(SubjectInfoAdapter());
    Hive.registerAdapter(SubjectAdapter());
    Hive.registerAdapter(RoleAdapter());
    Hive.registerAdapter(StandardsAdapter());
    Hive.registerAdapter(SectionAdapter());
    Hive.registerAdapter(AnnouncementTitleAdapter());
    Hive.registerAdapter(RouteeAdapter());
    Hive.registerAdapter(PointAdapter());
    Hive.registerAdapter(ModeAdapter());
    Hive.registerAdapter(VehicleAdapter());
    Hive.registerAdapter(VehicleDetailsAdapter());
    Hive.registerAdapter(CreateAttendanceAdapter());
    Hive.registerAdapter(AttendanceStudentAdapter());
    Hive.registerAdapter(PersonTypeAdapter());
    Hive.registerAdapter(ExpenseTypeAdapter());
    Hive.registerAdapter(ExpenseTypeDetailAdapter());
    Hive.registerAdapter(DetailAdapter());
    Hive.registerAdapter(ExpenseModeAdapter());
    Hive.registerAdapter(StorageAdapter());
    Hive.registerAdapter(StorageItemAdapter());
    Hive.registerAdapter(BranchAdapter());

    await Hive.openBox<RoleActions>('getActionsByRole-v2');
    await Hive.openBox<UserInfo>('userInfo-v2');
    await Hive.openBox<Standards>('standards-v2');
    await Hive.openBox<AnnouncementTitle>('announcementTitle-v2');
    await Hive.openBox<List<Routee>>('routes-v2');
    await Hive.openBox<Vehicle>('vehicle-v2');
    await Hive.openBox<VehicleDetails>('vehicleDetails-v2');
    await Hive.openBox<CreateAttendance>('createAttendance-v2');
    await Hive.openBox<PersonType>('personTypes-v2');
    await Hive.openBox<String>('fuelPriceBox-v2');
    await Hive.openBox<Branch>('zonalBranch-v2');
    await Hive.openBox<ExpenseType>('expenseTypes-v2');
    await Hive.openBox<Detail>('expenseCategory-v2');
    // await Hive.openBox<List<Detail>>('expenseSubCategory-v2');
    await Hive.openBox<StorageItem>('fuelStorage-v2');
    await Hive.openBox<String>('fcmToken-v1');
  }

  static Future<void> clearAll() async {
    await getActionsByRoleBox.clear();
    await userInfoBox.clear();
    await standardsBox.clear();
    await announcementTitleBox.clear();
    await routeBox.clear();
    await createAttendanceBox.clear();
    await vehicleBox.clear();
    await vehicleDetailsBox.clear();
    await fuelPriceBox.clear();
    await zonalBranch.clear();
    await expenseTypesBox.clear();
    await expenseCategorysBox.clear();
    // await expenseSubCategorysBox.clear();
    await fuelStorageBox.clear();
    await fcmTokenBox.clear();
  }
}
