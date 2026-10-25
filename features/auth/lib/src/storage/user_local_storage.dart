import 'package:auth/src/models/branches.dart';
import 'package:auth/src/models/person_types.dart';
import 'package:auth/src/models/role_actions.dart';
import 'package:auth/src/models/user_info.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';
import 'package:local_storage/local_storage.dart';

@lazySingleton
class UserLocalStorage {
  UserLocalStorage(this._storageService) {
    _ensureAdaptersRegistered();
  }

  final StorageService _storageService;

  void _ensureAdaptersRegistered() {
    if (!Hive.isAdapterRegistered(UserInfoAdapter().typeId)) {
      Hive.registerAdapter(UserInfoAdapter());
    }
    if (!Hive.isAdapterRegistered(UserClassAdapter().typeId)) {
      Hive.registerAdapter(UserClassAdapter());
    }
    if (!Hive.isAdapterRegistered(RoleAdapter().typeId)) {
      Hive.registerAdapter(RoleAdapter());
    }
    if (!Hive.isAdapterRegistered(RoleActionsAdapter().typeId)) {
      Hive.registerAdapter(RoleActionsAdapter());
    }
    if (!Hive.isAdapterRegistered(BranchAdapter().typeId)) {
      Hive.registerAdapter(BranchAdapter());
    }
    if (!Hive.isAdapterRegistered(PersonTypeAdapter().typeId)) {
      Hive.registerAdapter(PersonTypeAdapter());
    }
  }

  bool get isBoxOpen => _storageService.isBoxOpen(StorageConstants.userInfoBox);

  /// Pre-opens core auth and user data boxes on app startup.
  Future<void> init() async {
    _ensureAdaptersRegistered();
    await Future.wait([
      _storageService.openBox<UserInfo>(StorageConstants.userInfoBox),
      _storageService.openBox<RoleActions>(
        StorageConstants.getActionsByRoleBox,
      ),
      _storageService.openBox<Branch>(StorageConstants.zonalBranchBox),
      _storageService.openBox<PersonType>(StorageConstants.personTypesBox),
    ]);
  }

  // --- User Info ---

  Future<void> saveUser(UserInfo user) async {
    _ensureAdaptersRegistered();
    final box = await _storageService.openBox<UserInfo>(
      StorageConstants.userInfoBox,
    );
    await box.clear();
    await box.add(user);
    await box.put(StorageConstants.currentUserKey, user);
  }

  Future<UserInfo?> getUserAsync() async {
    _ensureAdaptersRegistered();
    if (!isBoxOpen) {
      await init();
    }
    return getUser();
  }

  UserInfo? getUser() {
    _ensureAdaptersRegistered();
    if (!_storageService.isBoxOpen(StorageConstants.userInfoBox)) {
      return null;
    }
    final box = _storageService.getBox<UserInfo>(StorageConstants.userInfoBox);

    final userByKey = box.get(StorageConstants.currentUserKey);
    if (userByKey != null) return userByKey;

    if (box.isNotEmpty) {
      return box.values.last;
    }

    return null;
  }

  String? getToken() {
    final user = getUser();
    if (user == null || user.token.isEmpty) return null;
    return user.token;
  }

  Future<void> clearUser() async {
    _ensureAdaptersRegistered();
    final box = await _storageService.openBox<UserInfo>(
      StorageConstants.userInfoBox,
    );
    await box.clear();
  }

  // --- Role Actions ---

  Future<void> saveRoleActions(List<RoleActions> actions) async {
    _ensureAdaptersRegistered();
    final box = await _storageService.openBox<RoleActions>(
      StorageConstants.getActionsByRoleBox,
    );
    await box.clear();
    await box.addAll(actions);
  }

  List<RoleActions> getRoleActions() {
    _ensureAdaptersRegistered();
    if (!_storageService.isBoxOpen(StorageConstants.getActionsByRoleBox)) {
      return <RoleActions>[];
    }
    final box = _storageService.getBox<RoleActions>(
      StorageConstants.getActionsByRoleBox,
    );
    return box.values.toList();
  }

  // --- Zonal Branch ---

  Future<void> saveSelectedBranch(Branch branch) async {
    _ensureAdaptersRegistered();
    final box = await _storageService.openBox<Branch>(
      StorageConstants.zonalBranchBox,
    );
    await box.put('selected', branch);
  }

  Branch? getSelectedBranch() {
    _ensureAdaptersRegistered();
    if (!_storageService.isBoxOpen(StorageConstants.zonalBranchBox)) {
      return null;
    }
    final box = _storageService.getBox<Branch>(StorageConstants.zonalBranchBox);
    return box.get('selected');
  }

  Future<void> clearSelectedBranch() async {
    _ensureAdaptersRegistered();
    final box = await _storageService.openBox<Branch>(
      StorageConstants.zonalBranchBox,
    );
    await box.delete('selected');
  }

  // --- Person Types ---

  Future<void> savePersonTypes(List<PersonType> types) async {
    _ensureAdaptersRegistered();
    final box = await _storageService.openBox<PersonType>(
      StorageConstants.personTypesBox,
    );
    await box.clear();
    await box.addAll(types);
  }

  List<PersonType> getPersonTypes() {
    _ensureAdaptersRegistered();
    if (!_storageService.isBoxOpen(StorageConstants.personTypesBox)) {
      return <PersonType>[];
    }
    final box = _storageService.getBox<PersonType>(
      StorageConstants.personTypesBox,
    );
    return box.values.toList();
  }

  // --- Clear All Storage ---

  Future<void> clearAll() async {
    await _storageService.clearAll();
  }

  // --- FCM Token ---

  Future<void> saveFcmToken(String token) async {
    await _storageService.put<String>(
      StorageConstants.fcmTokenBox,
      StorageConstants.fcmTokenKey,
      token,
    );
  }

  String? getFcmToken() {
    return _storageService.get<String>(
      StorageConstants.fcmTokenBox,
      StorageConstants.fcmTokenKey,
    );
  }
}
