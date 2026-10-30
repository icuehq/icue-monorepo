import 'package:api_client/api_client.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports/reports.dart';

class MockApiClient extends Fake implements ApiClient {
  dynamic nextResponseData;
  String? lastPath;
  dynamic lastData;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    lastPath = path;
    lastData = data;
    return Response<T>(
      data: nextResponseData as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  group('Reports Models Serialization', () {
    test('FuelReading and FuelReport deserialize and serialize properly', () {
      final json = <String, dynamic>{
        '_id': 'fuel_123',
        'ZoneId': 1,
        'BranchId': 2,
        'VehicleNumber': 'KA01AB1234',
        'TotalNoOfFuelReadings': 1,
        'FUELREADING': [
          {
            'Speedometer': 12500,
            'FuelFilled': 45.5,
            'Image': 'https://example.com/fuel.png',
            'Date': '2026-10-30',
            'Time': '08:30 AM',
            'ImgMode': 'AUTO',
            'DateTime': '2026-10-30T08:30:00.000Z',
          }
        ],
      };

      final report = FuelReport.fromJson(json);
      expect(report.id, 'fuel_123');
      expect(report.vehicleNumber, 'KA01AB1234');
      expect(report.fuelReadings.length, 1);
      expect(report.fuelReadings.first.speedometer, 12500);
      expect(report.fuelReadings.first.fuelFilled, 45.5);

      final out = report.toJson();
      expect(out['VehicleNumber'], 'KA01AB1234');
      expect((out['FUELREADING'] as List).length, 1);
    });

    test('MileageReportItem deserializes and serializes properly', () {
      final json = <String, dynamic>{
        'VehicleNumber': 'KA01AB1234',
        'RouteNo': 'R-101',
        'ActualTotalKmsDriven': 42.5,
        'TotalNoOfKMReadingsTaken': 4,
        'SPEEDOMETERDIFF': '45',
      };

      final item = MileageReportItem.fromJson(json);
      expect(item.vehicleNumber, 'KA01AB1234');
      expect(item.routeNo, 'R-101');
      expect(item.actualTotalKmsDriven, 42.5);
      expect(item.speedometerDiff, '45');

      final out = item.toJson();
      expect(out['RouteNo'], 'R-101');
      expect(out['SPEEDOMETERDIFF'], '45');
    });

    test('OverSpeedReportItem and OverSpeedDatum parse correctly', () {
      final json = <String, dynamic>{
        'VehicleNumber': 'KA01AB1234',
        'DriverName': 'John Doe',
        'DriverMobile': 9876543210,
        'Mode': 'Pickup',
        'RouteNo': 'R-1',
        'StartPoint': 'Point A',
        'EndPoint': 'Point B',
        'StartTime': '07:00 AM',
        'EndTime': '08:00 AM',
        'StartDate': '2026-10-30',
        'AverageSpeed': 45.2,
        'OverSpeedData': [
          {'speed': 65.5, 'gpsTime': 1761840000000}
        ],
      };

      final item = OverSpeedReportItem.fromJson(json);
      expect(item.vehicleNumber, 'KA01AB1234');
      expect(item.driverName, 'John Doe');
      expect(item.overSpeedData.length, 1);
      expect(item.overSpeedData.first.speed, 65.5);
    });

    test('CleaningReportResponse and CleanedPartItem deserialize properly', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'metadata': {'total': 1, 'page': 1, 'pagesize': 10},
        'data': [
          {
            'VehicleNo': 'KA01AB1234',
            'CreatedBy': 'Supervisor',
            'CreatedDate': '2026-10-30',
            'CreatedTime': '06:00 AM',
            'Source': 'adminapp',
            'Photos': ['https://example.com/clean.jpg'],
            'CleanedData': [
              {'Id': 1, 'Name': 'Windshield', 'Status': 'Cleaned'},
            ],
          }
        ],
      };

      final res = CleaningReportResponse.fromJson(json);
      expect(res.err, false);
      expect(res.metadata.total, 1);
      expect(res.data.length, 1);
      expect(res.data.first.vehicleNo, 'KA01AB1234');
      expect(res.data.first.cleanedData.first.name, 'Windshield');
    });

    test('AlcoholReportResponse and Record parse driver breathalyzer results', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'metadata': {'total': 1, 'page': 1, 'pagesize': 10},
        'data': [
          {
            'Id': 55,
            'SubmittedDate': '2026-10-30',
            'SubmittedTime': '06:30 AM',
            'PersonType': 'DRIVER',
            'PersonInfo': {'Name': 'Michael Driver', 'Mobile': '9988776655'},
            'AlcoholTest': 'PASSED',
            'AlcoholTestReading': 0.0,
            'ImageUrl': 'https://example.com/test.jpg',
            'CreatedBy': 'Safety Officer',
          }
        ],
      };

      final res = AlcoholReportResponse.fromJson(json);
      expect(res.data.length, 1);
      expect(res.data.first.personName, 'Michael Driver');
      expect(res.data.first.alcoholTest, 'PASSED');
      expect(res.data.first.alcoholTestReading, 0.0);
    });

    test('ArrivalTimeReportResponse and ArrivalTimeItem deserialize properly', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'data': {
          'metadata': {'total': 1, 'page': 1, 'pagesize': 10},
          'data': [
            {
              'VehicleNumber': 'KA01AB1234',
              'RouteNo': 'R-1',
              'Mode': 'Pickup',
              'StartDate': '2026-10-30',
              'StartTime': '07:00 AM',
              'EndDate': '2026-10-30',
              'EndTime': '08:15 AM',
              'ArrivalTime': '08:10 AM',
            }
          ],
        },
      };

      final res = ArrivalTimeReportResponse.fromJson(json);
      expect(res.metadata.total, 1);
      expect(res.data.length, 1);
      expect(res.data.first.vehicleNumber, 'KA01AB1234');
      expect(res.data.first.arrivalTime, '08:10 AM');
    });
  });

  group('ReportsProvider State Management', () {
    late MockApiClient mockApi;
    late ReportsService service;
    late ReportsProvider provider;

    setUp(() {
      mockApi = MockApiClient();
      service = ReportsService(mockApi);
      provider = ReportsProvider(service);
    });

    test('fetchFuelReadings loads readings into provider', () async {
      mockApi.nextResponseData = [
        {
          '_id': '1',
          'ZoneId': 1,
          'BranchId': 1,
          'VehicleNumber': 'KA01AB1234',
          'TotalNoOfFuelReadings': 1,
          'FUELREADING': [
            {
              'Speedometer': 12000,
              'FuelFilled': 50.0,
              'Date': '2026-10-30',
              'Time': '09:00 AM',
              'DateTime': '2026-10-30T09:00:00.000Z',
            }
          ],
        }
      ];

      await provider.fetchFuelReadings(
        vehicleNumber: 'KA01AB1234',
        month: '10',
        year: '2026',
      );

      expect(mockApi.lastPath, '/v2.0/getVehicleFuelReadingReport');
      expect(provider.fuelReadings.length, 1);
      expect(provider.fuelReadings.first.speedometer, 12000);
      expect(provider.isLoading, false);
    });

    test('fetchMileageReports loads mileage list into provider', () async {
      mockApi.nextResponseData = [
        {
          'VehicleNumber': 'KA01AB1234',
          'RouteNo': 'R-1',
          'ActualTotalKmsDriven': 30,
          'TotalNoOfKMReadingsTaken': 2,
          'SPEEDOMETERDIFF': '35',
        }
      ];

      await provider.fetchMileageReports(
        vehicleNumber: 'KA01AB1234',
        month: '10',
        year: '2026',
      );

      expect(mockApi.lastPath, '/v1.0/getVehicleMileageReport');
      expect(provider.mileageReports.length, 1);
      expect(provider.mileageReports.first.routeNo, 'R-1');
    });

    test('fetchOverSpeedReports flattens violations into records', () async {
      mockApi.nextResponseData = [
        {
          'VehicleNumber': 'KA01AB1234',
          'DriverName': 'John',
          'DriverMobile': 1234567890,
          'Mode': 'Pickup',
          'RouteNo': 'R-1',
          'AverageSpeed': 40.0,
          'OverSpeedData': [
            {'speed': 70.0, 'gpsTime': 1761840000000}
          ],
        }
      ];

      await provider.fetchOverSpeedReports(
        vehicleNumber: 'KA01AB1234',
        month: '10',
        year: '2026',
        speedLimit: '50',
      );

      expect(mockApi.lastPath, '/v1.0/getVehicleOverSpeedReport');
      expect(provider.overSpeedList.length, 1);
      expect(provider.overSpeedList.first.speed, 70.0);
    });

    test('fetchCleaningReport handles date filtering and pagination', () async {
      mockApi.nextResponseData = {
        'err': false,
        'message': 'Success',
        'metadata': {'total': 1, 'page': 1, 'pagesize': 10},
        'data': [
          {
            'VehicleNo': 'KA01AB1234',
            'CleanedData': [
              {'Id': 1, 'Name': 'Interior', 'Status': 'Clean'}
            ],
          }
        ],
      };

      final filter = AppFilterResult.byMonth(month: '10', year: '2026');
      await provider.fetchCleaningReport(filter: filter);

      expect(mockApi.lastPath, '/v1.0/getVhCleanedReport');
      expect(provider.cleaningReports.length, 1);
      expect(provider.cleaningMetadata?.total, 1);
    });

    test('fetchAlcoholTestReport loads alcohol records', () async {
      mockApi.nextResponseData = {
        'err': false,
        'message': 'Success',
        'metadata': {'total': 1, 'page': 1, 'pagesize': 10},
        'data': [
          {
            'Id': 1,
            'PersonInfo': {'Name': 'Driver A', 'Mobile': '999'},
            'AlcoholTest': 'PASSED',
            'AlcoholTestReading': 0.0,
          }
        ],
      };

      final filter = AppFilterResult.byDate(DateTime(2026, 10, 30));
      await provider.fetchAlcoholTestReport(filter: filter);

      expect(mockApi.lastPath, '/v2.0/getPrsnAlcoholTestReport');
      expect(provider.alcoholTestReports.length, 1);
    });

    test('fetchArrivalTimeReport loads arrival records', () async {
      mockApi.nextResponseData = {
        'err': false,
        'message': 'Success',
        'data': {
          'metadata': {'total': 1, 'page': 1, 'pagesize': 10},
          'data': [
            {
              'VehicleNumber': 'KA01AB1234',
              'RouteNo': 'R-1',
              'Mode': 'Pickup',
              'StartDate': '2026-10-30',
              'StartTime': '07:00 AM',
            }
          ],
        },
      };

      final filter = AppFilterResult.byRange(
        DateTimeRange(
          start: DateTime(2026, 10),
          end: DateTime(2026, 10, 30),
        ),
      );
      await provider.fetchArrivalTimeReport(filter: filter);

      expect(mockApi.lastPath, '/v2.0/getVhArrivalTime');
      expect(provider.arrivalTimeReports.length, 1);
    });

    test('clearData resets all provider lists and metadata', () {
      provider.clearData();
      expect(provider.fuelReadings, isEmpty);
      expect(provider.mileageReports, isEmpty);
      expect(provider.overSpeedList, isEmpty);
      expect(provider.cleaningReports, isEmpty);
      expect(provider.cleaningMetadata, isNull);
      expect(provider.alcoholTestReports, isEmpty);
      expect(provider.alcoholMetadata, isNull);
      expect(provider.arrivalTimeReports, isEmpty);
      expect(provider.arrivalMetadata, isNull);
    });
  });
}
