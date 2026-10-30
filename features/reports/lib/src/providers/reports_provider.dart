import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:reports/src/models/alcohol_test_report.dart';
import 'package:reports/src/models/arrival_time_report.dart';
import 'package:reports/src/models/cleaning_report.dart';
import 'package:reports/src/models/fuel_report.dart';
import 'package:reports/src/models/mileage_report.dart';
import 'package:reports/src/models/overspeed_report.dart';
import 'package:reports/src/models/report_metadata.dart';
import 'package:reports/src/services/reports_service.dart';

@lazySingleton
class ReportsProvider extends ChangeNotifier {
  ReportsProvider(this._reportsService);

  final ReportsService _reportsService;

  bool _isLoading = false;
  String? _errorMessage;

  List<FuelReading> _fuelReadings = <FuelReading>[];
  List<MileageReportItem> _mileageReports = <MileageReportItem>[];
  List<OverSpeedRecord> _overSpeedList = <OverSpeedRecord>[];

  List<CleaningReportData> _cleaningReports = <CleaningReportData>[];
  ReportMetadata? _cleaningMetadata;

  List<AlcoholTestRecord> _alcoholTestReports = <AlcoholTestRecord>[];
  ReportMetadata? _alcoholMetadata;

  List<ArrivalTimeItem> _arrivalTimeReports = <ArrivalTimeItem>[];
  ReportMetadata? _arrivalMetadata;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<FuelReading> get fuelReadings => List.unmodifiable(_fuelReadings);
  List<MileageReportItem> get mileageReports =>
      List.unmodifiable(_mileageReports);
  List<OverSpeedRecord> get overSpeedList => List.unmodifiable(_overSpeedList);

  List<CleaningReportData> get cleaningReports =>
      List.unmodifiable(_cleaningReports);
  ReportMetadata? get cleaningMetadata => _cleaningMetadata;

  List<AlcoholTestRecord> get alcoholTestReports =>
      List.unmodifiable(_alcoholTestReports);
  ReportMetadata? get alcoholMetadata => _alcoholMetadata;

  List<ArrivalTimeItem> get arrivalTimeReports =>
      List.unmodifiable(_arrivalTimeReports);
  ReportMetadata? get arrivalMetadata => _arrivalMetadata;

  void clearData() {
    _fuelReadings.clear();
    _mileageReports.clear();
    _overSpeedList.clear();
    _cleaningReports.clear();
    _cleaningMetadata = null;
    _alcoholTestReports.clear();
    _alcoholMetadata = null;
    _arrivalTimeReports.clear();
    _arrivalMetadata = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Converts core_ui [AppFilterResult] to backend report mode string.
  String _mapReportMode(AppFilterResult filter) {
    switch (filter.mode) {
      case AppFilterMode.byMonth:
        return 'bymonth';
      case AppFilterMode.byDate:
        return 'bydate';
      case AppFilterMode.byRange:
        return 'byperiod';
    }
  }

  /// Loads fuel readings for vehicle, month and year.
  Future<void> fetchFuelReadings({
    required String vehicleNumber,
    required String month,
    required String year,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fuelReadings.clear();
    notifyListeners();

    try {
      _fuelReadings = await _reportsService.getFuelReadingReport(
        vehicleNumber: vehicleNumber,
        month: month,
        year: year,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads mileage reports for vehicle, month and year.
  Future<void> fetchMileageReports({
    required String vehicleNumber,
    required String month,
    required String year,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _mileageReports.clear();
    notifyListeners();

    try {
      _mileageReports = await _reportsService.getMileageReport(
        vehicleNumber: vehicleNumber,
        month: month,
        year: year,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads overspeed events for vehicle, month, year, and threshold limit.
  Future<void> fetchOverSpeedReports({
    required String vehicleNumber,
    required String month,
    required String year,
    required String speedLimit,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _overSpeedList.clear();
    notifyListeners();

    try {
      _overSpeedList = await _reportsService.getOverSpeedReport(
        vehicleNumber: vehicleNumber,
        month: month,
        year: year,
        speedLimit: speedLimit,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads paginated cleaning inspection reports.
  Future<void> fetchCleaningReport({
    required AppFilterResult filter,
    int page = 1,
    int? vehicleId,
    String? vehicleNo,
  }) async {
    if (page == 1) {
      _isLoading = true;
      _cleaningReports.clear();
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final modeStr = _mapReportMode(filter);
      final res = await _reportsService.getCleaningReport(
        reportMode: modeStr,
        month: filter.month,
        year: filter.year,
        startDate: filter.mode == AppFilterMode.byDate
            ? filter.date
            : filter.range?.start,
        endDate: filter.mode == AppFilterMode.byRange
            ? filter.range?.end
            : filter.date,
        page: page,
        vehicleId: vehicleId,
        vehicleNo: vehicleNo,
      );

      _cleaningMetadata = res.metadata;
      if (page == 1) {
        _cleaningReports = List.of(res.data);
      } else {
        _cleaningReports.addAll(res.data);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads paginated breathalyzer alcohol reports.
  Future<void> fetchAlcoholTestReport({
    required AppFilterResult filter,
    int page = 1,
    int? personId,
  }) async {
    if (page == 1) {
      _isLoading = true;
      _alcoholTestReports.clear();
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final modeStr = _mapReportMode(filter);
      final res = await _reportsService.getAlcoholTestReport(
        reportMode: modeStr,
        month: filter.month,
        year: filter.year,
        startDate: filter.mode == AppFilterMode.byDate
            ? filter.date
            : filter.range?.start,
        endDate: filter.mode == AppFilterMode.byRange
            ? filter.range?.end
            : filter.date,
        page: page,
        personId: personId,
      );

      _alcoholMetadata = res.metadata;
      if (page == 1) {
        _alcoholTestReports = List.of(res.data);
      } else {
        _alcoholTestReports.addAll(res.data);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads paginated vehicle arrival time reports.
  Future<void> fetchArrivalTimeReport({
    required AppFilterResult filter,
    String mode = 'Pickup',
    int page = 1,
    String? vehicleNo,
  }) async {
    if (page == 1) {
      _isLoading = true;
      _arrivalTimeReports.clear();
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final modeStr = _mapReportMode(filter);
      final res = await _reportsService.getArrivalTimeReport(
        reportMode: modeStr,
        mode: mode,
        month: filter.month,
        year: filter.year,
        startDate: filter.mode == AppFilterMode.byDate
            ? filter.date
            : filter.range?.start,
        endDate: filter.mode == AppFilterMode.byRange
            ? filter.range?.end
            : filter.date,
        page: page,
        vehicleNo: vehicleNo,
      );

      _arrivalMetadata = res.metadata;
      if (page == 1) {
        _arrivalTimeReports = List.of(res.data);
      } else {
        _arrivalTimeReports.addAll(res.data);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
