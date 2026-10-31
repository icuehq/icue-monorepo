import 'package:api_client/api_client.dart';
import 'package:core_ui/core_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:reports/src/models/alcohol_test_report.dart';
import 'package:reports/src/models/arrival_time_report.dart';
import 'package:reports/src/models/cleaning_report.dart';
import 'package:reports/src/models/fuel_report.dart';
import 'package:reports/src/models/mileage_report.dart';
import 'package:reports/src/models/overspeed_report.dart';

@lazySingleton
class ReportsService {
  const ReportsService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches monthly fuel readings for a specific vehicle.
  Future<List<FuelReading>> getFuelReadingReport({
    required String vehicleNumber,
    required String month,
    required String year,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v2.0/getVehicleFuelReadingReport',
      data: <String, dynamic>{
        'Month': month,
        'Year': year,
        'VehicleNumber': vehicleNumber,
      },
    );

    if (response.data is List) {
      final list = (response.data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(FuelReport.fromJson)
          .toList();
      if (list.isNotEmpty) {
        return list.first.fuelReadings;
      }
    }
    return <FuelReading>[];
  }

  /// Fetches mileage report for a specific vehicle.
  Future<List<MileageReportItem>> getMileageReport({
    required String vehicleNumber,
    required String month,
    required String year,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVehicleMileageReport',
      data: <String, dynamic>{
        'Month': month,
        'Year': year,
        'VehicleNumber': vehicleNumber,
      },
    );

    if (response.data is List) {
      return (response.data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MileageReportItem.fromJson)
          .toList();
    }
    return <MileageReportItem>[];
  }

  /// Fetches vehicle overspeed instances for a given speed limit.
  Future<List<OverSpeedRecord>> getOverSpeedReport({
    required String vehicleNumber,
    required String month,
    required String year,
    required String speedLimit,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVehicleOverSpeedReport',
      data: <String, dynamic>{
        'Month': month,
        'Year': year,
        'speedLimit': speedLimit,
        'VehicleNumber': vehicleNumber,
      },
    );

    final records = <OverSpeedRecord>[];
    if (response.data is List) {
      final reports = (response.data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(OverSpeedReportItem.fromJson)
          .toList();

      for (final report in reports) {
        for (final item in report.overSpeedData) {
          records.add(
            OverSpeedRecord(
              vehicleNumber: report.vehicleNumber,
              mode: report.mode,
              routeNo: report.routeNo,
              averageSpeed: report.averageSpeed,
              speed: item.speed,
              gpsTime: DateTime.fromMillisecondsSinceEpoch(item.gpsTime),
              driverName: report.driverName,
              driverMobile: report.driverMobile,
            ),
          );
        }
      }
    }
    return records;
  }

  /// Fetches vehicle cleaning inspection report with pagination and date filter.
  Future<CleaningReportResponse> getCleaningReport({
    required String reportMode,
    String? month,
    String? year,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 10,
    int? vehicleId,
    String? vehicleNo,
  }) async {
    final payload = <String, dynamic>{
      'VehicleId': vehicleId,
      'VehicleNo': vehicleNo,
      'PageNumber': page,
      'PageSize': pageSize,
      'ReportMode': reportMode,
    };

    if (reportMode == 'bymonth') {
      payload['Month'] = month;
      payload['Year'] = year;
    } else {
      payload['FromDate'] = startDate != null
          ? AppDateUtils.formatUsDate(startDate)
          : null;
      payload['ToDate'] = endDate != null
          ? AppDateUtils.formatUsDate(endDate)
          : null;
    }

    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVhCleanedReport',
      data: payload,
    );

    if (response.data is Map<String, dynamic>) {
      return CleaningReportResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return const CleaningReportResponse();
  }

  /// Fetches driver breathalyzer alcohol test report.
  Future<AlcoholReportResponse> getAlcoholTestReport({
    required String reportMode,
    String? month,
    String? year,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 10,
    int? personId,
  }) async {
    final payload = <String, dynamic>{
      'PersonId': personId,
      'PageNumber': page,
      'PageSize': pageSize,
      'ReportMode': reportMode,
    };

    if (reportMode == 'bymonth') {
      payload['Month'] = month;
      payload['Year'] = year;
    } else {
      payload['FromDate'] = startDate != null
          ? AppDateUtils.formatUsDate(startDate)
          : null;
      payload['ToDate'] = endDate != null
          ? AppDateUtils.formatUsDate(endDate)
          : null;
    }

    final response = await _apiClient.post<dynamic>(
      '/v2.0/getPrsnAlcoholTestReport',
      data: payload,
    );

    if (response.data is Map<String, dynamic>) {
      return AlcoholReportResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return const AlcoholReportResponse();
  }

  /// Fetches vehicle arrival times by trip mode and route.
  Future<ArrivalTimeReportResponse> getArrivalTimeReport({
    required String reportMode,
    String mode = 'Pickup',
    String? month,
    String? year,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 10,
    String? vehicleNo,
  }) async {
    final payload = <String, dynamic>{
      'Mode': mode,
      'PageNumber': page,
      'PageSize': pageSize,
      'VehicleNo': vehicleNo,
      'ReportMode': reportMode,
    };

    if (reportMode == 'bymonth') {
      payload['Month'] = month;
      payload['Year'] = year;
    } else {
      payload['FromDate'] = startDate != null
          ? AppDateUtils.formatUsDate(startDate)
          : null;
      payload['ToDate'] = endDate != null
          ? AppDateUtils.formatUsDate(endDate)
          : null;
    }

    final response = await _apiClient.post<dynamic>(
      '/v2.0/getVhArrivalTime',
      data: payload,
    );

    if (response.data is Map<String, dynamic>) {
      return ArrivalTimeReportResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return const ArrivalTimeReportResponse();
  }
}
