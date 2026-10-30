import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:logbook/src/models/alcohol_test.dart';
import 'package:logbook/src/models/cleaning_parts.dart';
import 'package:logbook/src/models/complaint_requests.dart';
import 'package:logbook/src/models/complaints.dart';
import 'package:logbook/src/models/complaints_dashboard.dart';
import 'package:logbook/src/services/logbook_service.dart';

@lazySingleton
class LogBookProvider extends ChangeNotifier {
  LogBookProvider(this._logBookService);

  final LogBookService _logBookService;

  List<ComplaintDashboardItem> _stats = <ComplaintDashboardItem>[];
  int _totalStats = 0;

  List<Complaint> _complaints = <Complaint>[];
  int _totalComplaints = 0;

  List<ComplaintCategory> _categories = <ComplaintCategory>[];
  List<CleaningPart> _cleaningParts = <CleaningPart>[];

  List<AlcoholTestItem> _alcoholTests = <AlcoholTestItem>[];
  int _totalAlcoholTests = 0;

  bool _isLoading = false;
  String? _errorMessage;

  List<ComplaintDashboardItem> get stats => List.unmodifiable(_stats);
  int get totalStats => _totalStats;

  List<Complaint> get complaints => List.unmodifiable(_complaints);
  int get totalComplaints => _totalComplaints;

  List<ComplaintCategory> get categories => List.unmodifiable(_categories);
  List<CleaningPart> get cleaningParts => List.unmodifiable(_cleaningParts);

  List<AlcoholTestItem> get alcoholTests => List.unmodifiable(_alcoholTests);
  int get totalAlcoholTests => _totalAlcoholTests;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearComplaints() {
    _complaints = <Complaint>[];
    _totalComplaints = 0;
    notifyListeners();
  }

  void clearStats() {
    _stats = <ComplaintDashboardItem>[];
    _totalStats = 0;
    notifyListeners();
  }

  /// Fetches complaints stats.
  Future<void> fetchComplaintsStats({
    required String countBy,
    int page = 1,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _logBookService.getComplaintsStats(
        countBy: countBy,
        page: page,
      );
      if (page == 1) {
        _stats = res.data;
      } else {
        _stats = [..._stats, ...res.data];
      }
      _totalStats = res.total;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches complaints list.
  Future<void> fetchComplaints({
    int? vehicleId,
    String? status,
    int? categoryId,
    String? action,
    String? complaintNo,
    int page = 1,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _logBookService.getComplaints(
        vehicleId: vehicleId,
        status: status,
        categoryId: categoryId,
        action: action,
        complaintNo: complaintNo,
        page: page,
      );
      if (page == 1) {
        _complaints = res.data;
      } else {
        _complaints = [..._complaints, ...res.data];
      }
      _totalComplaints = res.total;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches complaint categories.
  Future<void> fetchComplaintCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _categories = await _logBookService.getComplaintCategories();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new complaint.
  Future<bool> createComplaint(CreateComplaintRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _logBookService.submitComplaint(request);
      if (success) {
        await fetchComplaints();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates complaint status or resolution.
  Future<bool> updateComplaint(UpdateComplaintRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _logBookService.updateComplaint(request);
      if (success) {
        await fetchComplaints();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches cleaning inspection parts.
  Future<void> fetchCleaningParts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _cleaningParts = await _logBookService.getVehicleCleaningParts();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submits cleaning inspection records.
  Future<CleaningSubmissionResult> submitCleaningData(
    SubmitCleaningDataRequest request,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _logBookService.submitVehicleCleaning(request);
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      return const CleaningSubmissionResult(success: false, failedCount: 1);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submits an alcohol test record.
  Future<bool> submitAlcoholTest(AlcoholTestSubmissionRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _logBookService.submitAlcoholTest(request);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches alcohol test logs.
  Future<void> fetchAlcoholTestReport({
    int page = 1,
    String? search,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _logBookService.getAlcoholTestReport(
        page: page,
        search: search,
      );
      if (page == 1) {
        _alcoholTests = res.data;
      } else {
        _alcoholTests = [..._alcoholTests, ...res.data];
      }
      _totalAlcoholTests = res.total;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
