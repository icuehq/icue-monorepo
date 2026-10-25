import 'package:api_client/api_client.dart';
import 'package:auth/src/models/assigned_entities.dart';
import 'package:auth/src/models/branches.dart';
import 'package:auth/src/models/person_types.dart';
import 'package:auth/src/models/role_actions.dart';
import 'package:auth/src/models/user_info.dart';
import 'package:auth/src/services/auth_service.dart';
import 'package:auth/src/storage/session_token_provider.dart';
import 'package:auth/src/storage/user_local_storage.dart';
import 'package:auth/src/utils/indian_phone_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Steps in the two-stage authentication flow.
enum AuthStep { requestOtp, verifyOtp, authenticated }

@lazySingleton
class AuthProvider extends ChangeNotifier {
  AuthProvider(
    this._authService,
    this._userLocalStorage,
    SessionTokenProvider sessionTokenProvider,
  ) {
    sessionTokenProvider.onSessionExpired = _handleSessionExpired;
    _initFromStorage();
    if (user == null) {
      restoreSession();
    }
  }

  final AuthService _authService;
  final UserLocalStorage _userLocalStorage;

  // --- State Properties matching existing AuthProvider ---
  UserInfo? user;
  bool loading = false;
  bool otpSent = false;
  List<RoleActions> roleActions = <RoleActions>[];
  List<Branch> branches = <Branch>[];
  Branch? selectedBranch;
  List<PersonType> personTypes = <PersonType>[];
  List<AssignedEntityClass> assignedEntityClasses = <AssignedEntityClass>[];

  AuthStep _step = AuthStep.requestOtp;
  String? _errorMessage;
  String _username = '';
  String? _receivedPin;

  // --- Getters ---
  AuthStep get step => _step;
  bool get isLoading => loading;
  String? get errorMessage => _errorMessage;
  String get username => _username;
  String? get receivedPin => _receivedPin;
  bool get isAuthenticated => user != null && _step == AuthStep.authenticated;

  /// Whether current user is a Fleet Zonal Admin or Fleet Zonal Supervisor.
  bool get isZonalAdminOrSupervisor {
    final roleName = user?.roles.firstOrNull?.name.toLowerCase();
    return roleName == 'fleet_zonaladmin' ||
        roleName == 'fleet_zonalsupervisor';
  }

  /// Whether user must pick a branch before continuing to the main dashboard.
  bool get needsBranchSelection {
    return isAuthenticated &&
        isZonalAdminOrSupervisor &&
        selectedBranch == null;
  }

  void _initFromStorage() {
    final storedUser = _userLocalStorage.getUser();
    selectedBranch = _userLocalStorage.getSelectedBranch();
    roleActions = _userLocalStorage.getRoleActions();
    personTypes = _userLocalStorage.getPersonTypes();

    if (storedUser != null && storedUser.token.isNotEmpty) {
      user = storedUser;
      _username = storedUser.userName;
      _step = AuthStep.authenticated;
    }
  }

  /// Restores active user session asynchronously from local storage.
  Future<void> restoreSession() async {
    final storedUser = await _userLocalStorage.getUserAsync();
    selectedBranch = _userLocalStorage.getSelectedBranch();
    roleActions = _userLocalStorage.getRoleActions();
    personTypes = _userLocalStorage.getPersonTypes();

    if (storedUser != null && storedUser.token.isNotEmpty) {
      user = storedUser;
      _username = storedUser.userName;
      _step = AuthStep.authenticated;
      notifyListeners();
    }
  }

  /// Step 1: Requests OTP for [username] against `/v2.0/getloginotp`.
  Future<bool> sendLoginOtp(String rawUsername) async {
    final validationError = IndianPhoneValidator.validate(rawUsername);
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }

    loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final normalizedUsername = IndianPhoneValidator.normalize(rawUsername);
      final response = await _authService.requestOtp(normalizedUsername);

      _username = normalizedUsername;
      _receivedPin = response.pin;
      otpSent = true;
      _step = AuthStep.verifyOtp;
      loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      loading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage =
          'Unable to send OTP. Please check your internet connection.';
      loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Alias for backward compatibility with requestOtp.
  Future<bool> requestOtp(String username) => sendLoginOtp(username);

  void resetOtpSent() {
    otpSent = false;
    notifyListeners();
  }

  /// Step 2: Verifies OTP and logs in against `/v2.0/login`.
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        username: username,
        password: password.trim(),
      );

      user = response;
      resetOtpSent();
      _step = AuthStep.authenticated;

      // If user is zonal admin/supervisor, fetch branches
      if (isZonalAdminOrSupervisor && selectedBranch == null) {
        await getBranchesByZoneId();
      } else {
        await getRoleActions();
      }

      loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e is UnauthorizedException || _isGenericUnauthorized(e.message)) {
        _errorMessage = 'Invalid OTP. Please check and try again.';
      } else {
        _errorMessage = e.message;
      }
      loading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to log in. Please check the OTP and try again.';
      loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Alias for backward compatibility with existing form callers.
  Future<bool> verifyOtpAndLogin({
    required String otp,
    String source = 'adminapp',
  }) => login(username: _username, password: otp);

  /// Fetches actions permitted for the current user role against `/v1.0/getActionsByRole`.
  Future<void> getRoleActions({bool isSplash = false}) async {
    if (user == null) {
      await logout();
      return;
    }

    loading = true;
    notifyListeners();

    try {
      roleActions = await _authService.getRoleActions();
    } catch (e) {
      // Keep cached role actions if available
      roleActions = _userLocalStorage.getRoleActions();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Fetches branches for zonal admin against `/v1.0/getBranchesByZoneId`.
  Future<void> getBranchesByZoneId() async {
    loading = true;
    notifyListeners();

    try {
      branches = await _authService.getBranchesByZoneId();
    } catch (_) {
      branches = <Branch>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Sets the active branch for a zonal admin/supervisor session.
  Future<void> selectZonalBranch(Branch branch) async {
    selectedBranch = branch;
    await _userLocalStorage.saveSelectedBranch(branch);
    await getRoleActions();
    notifyListeners();
  }

  /// Clears the currently selected zonal branch to allow picking another branch.
  Future<void> clearSelectedBranch() async {
    selectedBranch = null;
    await _userLocalStorage.clearSelectedBranch();
    notifyListeners();
  }

  /// Fetches person types against `/v1.0/getPersonTypes`.
  Future<void> getPersonTypes() async {
    loading = true;
    notifyListeners();

    try {
      personTypes = await _authService.getPersonTypes();
    } catch (_) {
      personTypes = _userLocalStorage.getPersonTypes();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Fetches assigned class and section entities against `/v1.0/getAssignedEntities`.
  Future<void> getAssignedEntities({bool forAttendance = false}) async {
    loading = true;
    notifyListeners();

    try {
      assignedEntityClasses = await _authService.getAssignedEntities(
        forAttendance: forAttendance,
      );
    } catch (_) {
      assignedEntityClasses = <AssignedEntityClass>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Navigates back from OTP verification to the username entry step.
  void backToRequestOtp() {
    _step = AuthStep.requestOtp;
    _errorMessage = null;
    _receivedPin = null;
    otpSent = false;
    notifyListeners();
  }

  /// Logs out the user and resets all local state and Hive boxes.
  Future<void> logout() async {
    loading = true;
    notifyListeners();

    try {
      await _authService.logout();
    } finally {
      user = null;
      _username = '';
      _receivedPin = null;
      otpSent = false;
      selectedBranch = null;
      roleActions = <RoleActions>[];
      branches = <Branch>[];
      personTypes = <PersonType>[];
      assignedEntityClasses = <AssignedEntityClass>[];
      _step = AuthStep.requestOtp;
      _errorMessage = null;
      loading = false;
      notifyListeners();
    }
  }

  void _handleSessionExpired() {
    user = null;
    _username = '';
    _receivedPin = null;
    otpSent = false;
    selectedBranch = null;
    roleActions = <RoleActions>[];
    branches = <Branch>[];
    personTypes = <PersonType>[];
    assignedEntityClasses = <AssignedEntityClass>[];
    _step = AuthStep.requestOtp;
    _errorMessage = 'Session expired. Please log in again.';
    notifyListeners();
  }

  bool _isGenericUnauthorized(String message) {
    final normalized = message.trim().toLowerCase().replaceAll(
      RegExp(r'[\s\-_\.]'),
      '',
    );
    return normalized == 'unauthorized' ||
        normalized == 'unauthorizedaccess' ||
        normalized == 'invalidcredentials';
  }
}
