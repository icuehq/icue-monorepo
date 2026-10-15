import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import '../models/leave_application.dart';
import '../models/leave_balance.dart';
import '../models/leave_request.dart';
import '../services/hive_service.dart';
import '../services/hrms_api_client.dart';

@lazySingleton
class LeaveProvider extends ChangeNotifier {
  LeaveProvider(this._hrmsApiClient);

  final HrmsApiClient _hrmsApiClient;

  bool _loading = false;
  bool _submitting = false;
  String? _errorMessage;
  List<LeaveBalance> _leaveBalances = [];
  int _selectedYear = DateTime.now().year;
  bool _onlyAccessibleLeaves = false;

  String _selectedAppliedStatus = 'Requested';
  final Map<String, List<LeaveApplication>> _appliedLeaves = {
    'Requested': [],
    'Approved': [],
    'Rejected': [],
  };
  final Map<String, bool> _loadingAppliedByStatus = {
    'Requested': false,
    'Approved': false,
    'Rejected': false,
  };
  final Map<String, bool> _hasLoadedAppliedByStatus = {
    'Requested': false,
    'Approved': false,
    'Rejected': false,
  };
  final Map<String, String?> _appliedErrorsByStatus = {
    'Requested': null,
    'Approved': null,
    'Rejected': null,
  };

  String _normalizeStatus(String status) {
    if (status.isEmpty) return 'Requested';
    final lower = status.toLowerCase();
    if (lower == 'approved') return 'Approved';
    if (lower == 'rejected') return 'Rejected';
    return 'Requested';
  }

  bool get loading => _loading;
  bool get submitting => _submitting;
  bool get loadingApplied => isAppliedLeavesLoading(_selectedAppliedStatus);
  String? get errorMessage =>
      _appliedErrorsByStatus[_selectedAppliedStatus] ?? _errorMessage;
  List<LeaveBalance> get leaveBalances => _leaveBalances;
  int get selectedYear => _selectedYear;
  bool get onlyAccessibleLeaves => _onlyAccessibleLeaves;
  String get selectedAppliedStatus => _selectedAppliedStatus;

  List<LeaveApplication> get currentAppliedLeaves =>
      getAppliedLeaves(_selectedAppliedStatus);

  List<LeaveApplication> getAppliedLeaves(String status) {
    final key = _normalizeStatus(status);
    return _appliedLeaves[key] ?? [];
  }

  bool isAppliedLeavesLoading(String status) {
    final key = _normalizeStatus(status);
    return _loadingAppliedByStatus[key] ?? false;
  }

  bool hasLoadedAppliedLeaves(String status) {
    final key = _normalizeStatus(status);
    return _hasLoadedAppliedByStatus[key] ?? false;
  }

  String? getAppliedLeavesError(String status) {
    final key = _normalizeStatus(status);
    return _appliedErrorsByStatus[key];
  }

  int appliedCount(String status) {
    final key = _normalizeStatus(status);
    return (_appliedLeaves[key] ?? []).length;
  }

  List<LeaveBalance> get displayedLeaves {
    if (_onlyAccessibleLeaves) {
      return _leaveBalances.where((l) => l.isEmpAccess).toList();
    }
    return _leaveBalances;
  }

  double get totalAllocated =>
      _leaveBalances.fold(0.0, (sum, item) => sum + item.allocatedDays);

  double get totalTaken =>
      _leaveBalances.fold(0.0, (sum, item) => sum + item.takenDays);

  double get totalBalance =>
      _leaveBalances.fold(0.0, (sum, item) => sum + item.remainingDays);

  void setFilterAccessibleOnly(bool value) {
    _onlyAccessibleLeaves = value;
    notifyListeners();
  }

  void setYear(int year, {int? employeeId}) {
    if (_selectedYear == year) return;
    _selectedYear = year;
    notifyListeners();
    fetchLeaveBalances(employeeId: employeeId, year: year);
  }

  Future<void> fetchLeaveBalances({
    int? employeeId,
    int? year,
    bool refresh = false,
  }) async {
    final targetYear = year ?? _selectedYear;
    _selectedYear = targetYear;

    final resolvedEmpId = employeeId ?? HiveService.currentUser?.id ?? 241;
    if (resolvedEmpId == 0) {
      _errorMessage = 'Employee profile not found. Please log in again.';
      notifyListeners();
      return;
    }

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final path = '/api/v1/leaves/by-empid/241/$targetYear';

    try {
      final response = await _hrmsApiClient.get(path);
      if (response.statusCode == 200 && response.data != null) {
        _leaveBalances = leaveBalanceListFromJson(response.data);
        _errorMessage = null;
      } else {
        _errorMessage = 'Failed to load leave balances.';
      }
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _hrmsApiClient.logCrash(path, error, stack);
      }
      _errorMessage = 'Failed to fetch leave balances. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> submitLeaveRequest(LeaveRequestPayload payload) async {
    _submitting = true;
    _errorMessage = null;
    notifyListeners();

    const path = '/api/v1/leaves';
    try {
      final response = await _hrmsApiClient.post(path, data: payload.toJson());

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300) {
        // Refresh leave balances so balances remain up-to-date
        await fetchLeaveBalances(employeeId: payload.employeeId, refresh: true);
        // Refresh requested leaves list if already loaded
        await fetchAppliedLeaves(
          employeeId: payload.employeeId,
          status: 'Requested',
          refresh: true,
        );
        return true;
      } else {
        _errorMessage = 'Failed to submit leave request.';
        return false;
      }
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _hrmsApiClient.logCrash(path, error, stack);
      }
      _errorMessage = 'Failed to submit leave request. Please try again.';
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void setAppliedStatus(String status, {int? employeeId}) {
    final normalized = _normalizeStatus(status);
    final isDifferentStatus = _selectedAppliedStatus != normalized;
    if (isDifferentStatus) {
      _selectedAppliedStatus = normalized;
      notifyListeners();
    }
    if (!hasLoadedAppliedLeaves(normalized) &&
        !isAppliedLeavesLoading(normalized)) {
      fetchAppliedLeaves(employeeId: employeeId, status: normalized);
    }
  }

  Future<void> fetchAppliedLeaves({
    int? employeeId,
    String? status,
    bool refresh = false,
  }) async {
    final targetStatus = _normalizeStatus(status ?? _selectedAppliedStatus);
    _selectedAppliedStatus = targetStatus;

    if (!refresh &&
        hasLoadedAppliedLeaves(targetStatus) &&
        !isAppliedLeavesLoading(targetStatus)) {
      return;
    }

    final resolvedEmpId = employeeId ?? HiveService.currentUser?.id ?? 241;
    if (resolvedEmpId == 0) {
      const errorMsg = 'Employee profile not found. Please log in again.';
      _appliedErrorsByStatus[targetStatus] = errorMsg;
      _errorMessage = errorMsg;
      notifyListeners();
      return;
    }

    _loadingAppliedByStatus[targetStatus] = true;
    _appliedErrorsByStatus[targetStatus] = null;
    _errorMessage = null;
    notifyListeners();

    final path = '/api/v1/leaves/by-id-status/241/$targetStatus';

    try {
      final response = await _hrmsApiClient.get(path);
      if (response.statusCode == 200 && response.data != null) {
        _appliedLeaves[targetStatus] = leaveApplicationListFromJson(
          response.data,
        );
        _hasLoadedAppliedByStatus[targetStatus] = true;
        _appliedErrorsByStatus[targetStatus] = null;
        _errorMessage = null;
      } else {
        final errorMsg = 'Failed to load applied leaves for $targetStatus.';
        _appliedErrorsByStatus[targetStatus] = errorMsg;
        _errorMessage = errorMsg;
      }
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _hrmsApiClient.logCrash(path, error, stack);
      }
      const errorMsg = 'Failed to fetch applied leaves. Please try again.';
      _appliedErrorsByStatus[targetStatus] = errorMsg;
      _errorMessage = errorMsg;
    } finally {
      _loadingAppliedByStatus[targetStatus] = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllAppliedLeaves({
    int? employeeId,
    bool refresh = false,
  }) async {
    await Future.wait([
      fetchAppliedLeaves(
        employeeId: employeeId,
        status: 'Requested',
        refresh: refresh,
      ),
      fetchAppliedLeaves(
        employeeId: employeeId,
        status: 'Approved',
        refresh: refresh,
      ),
      fetchAppliedLeaves(
        employeeId: employeeId,
        status: 'Rejected',
        refresh: refresh,
      ),
    ]);
  }
}
