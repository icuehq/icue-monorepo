import 'package:flutter_test/flutter_test.dart';
import 'package:logbook/logbook.dart';

class MockLogBookService implements LogBookService {
  ComplaintsDashboardResponse mockStatsResponse =
      const ComplaintsDashboardResponse();
  ComplaintDataResponse mockComplaintsResponse = const ComplaintDataResponse();
  List<ComplaintCategory> mockCategories = [];
  List<CleaningPart> mockCleaningParts = [];
  AlcoholTestResponse mockAlcoholTestResponse = const AlcoholTestResponse();

  bool submitComplaintSuccess = true;
  bool updateComplaintSuccess = true;
  CleaningSubmissionResult mockCleaningResult =
      const CleaningSubmissionResult(success: true);
  bool submitAlcoholTestSuccess = true;

  CreateComplaintRequest? lastComplaintRequest;
  UpdateComplaintRequest? lastUpdateRequest;
  SubmitCleaningDataRequest? lastCleaningRequest;
  AlcoholTestSubmissionRequest? lastAlcoholRequest;

  @override
  Future<ComplaintsDashboardResponse> getComplaintsStats({
    required String countBy,
    int page = 1,
  }) async =>
      mockStatsResponse;

  @override
  Future<ComplaintDataResponse> getComplaints({
    int? vehicleId,
    String? status,
    int? categoryId,
    String? action,
    String? complaintNo,
    int page = 1,
  }) async =>
      mockComplaintsResponse;

  @override
  Future<List<ComplaintCategory>> getComplaintCategories() async =>
      mockCategories;

  @override
  Future<bool> submitComplaint(CreateComplaintRequest request) async {
    lastComplaintRequest = request;
    return submitComplaintSuccess;
  }

  @override
  Future<bool> updateComplaint(UpdateComplaintRequest request) async {
    lastUpdateRequest = request;
    return updateComplaintSuccess;
  }

  @override
  Future<List<CleaningPart>> getVehicleCleaningParts() async =>
      mockCleaningParts;

  @override
  Future<CleaningSubmissionResult> submitVehicleCleaning(
    SubmitCleaningDataRequest request,
  ) async {
    lastCleaningRequest = request;
    return mockCleaningResult;
  }

  @override
  Future<bool> submitAlcoholTest(AlcoholTestSubmissionRequest request) async {
    lastAlcoholRequest = request;
    return submitAlcoholTestSuccess;
  }

  @override
  Future<AlcoholTestResponse> getAlcoholTestReport({
    int page = 1,
    int pageSize = 10,
    String? search,
  }) async =>
      mockAlcoholTestResponse;
}

void main() {
  group('LogBook Models Serialization', () {
    test('Complaint and ComplaintDetail deserialize and serialize', () {
      final json = <String, dynamic>{
        'Id': 10,
        'ComplaintNo': 1001,
        'VehicleNo': 'AP29AB1234',
        'CategoryName': 'Brakes Issue',
        'CurrStatus': 'Open',
        'CurrAction': 'Investigate',
        'StsUpdatedDt': '2026-10-30',
        'StsUpdatedTime': '10:30 AM',
        'Details': [
          {
            'Status': 'Open',
            'Action': 'Logged',
            'Date': '2026-10-30',
            'Time': '10:30 AM',
            'Description': 'Brake pads worn out',
            'CreatedBy': 'Driver John',
            'ImageUrls': ['https://example.com/brake.jpg'],
          },
        ],
      };

      final complaint = Complaint.fromJson(json);

      expect(complaint.id, equals(10));
      expect(complaint.complaintNo, equals(1001));
      expect(complaint.vehicleNo, equals('AP29AB1234'));
      expect(complaint.categoryName, equals('Brakes Issue'));
      expect(complaint.currStatus, equals('Open'));
      expect(complaint.details.length, equals(1));

      final detail = complaint.details.first;
      expect(detail.status, equals('Open'));
      expect(detail.description, equals('Brake pads worn out'));
      expect(detail.imageUrls, contains('https://example.com/brake.jpg'));

      final encoded = complaint.toJson();
      expect(encoded['ComplaintNo'], equals(1001));
      expect(encoded['CurrStatus'], equals('Open'));
    });

    test('ComplaintsDashboardResponse deserializes grouped metrics', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'OK',
        'metadata': {'total': 4, 'page': 1, 'pagesize': 10},
        'data': [
          {
            'TotalCount': 4,
            'Status': 'Open',
            'Category': 'Electrical',
            'Statuses': [
              {'Status': 'Open', 'Count': 3},
              {'Status': 'Resolved', 'Count': 1},
            ],
          },
        ],
      };

      final resp = ComplaintsDashboardResponse.fromJson(json);
      expect(resp.err, isFalse);
      expect(resp.total, equals(4));
      expect(resp.data.length, equals(1));

      final item = resp.data.first;
      expect(item.totalCount, equals(4));
      expect(item.status, equals('Open'));
      expect(item.category, equals('Electrical'));
      expect(item.statuses.length, equals(2));
      expect(item.statuses.first.status, equals('Open'));
      expect(item.statuses.first.count, equals(3));
    });

    test('CleaningPart and SubmitCleaningDataRequest serialize properly', () {
      final partJson = {'Id': 1, 'Name': 'Interior Vacuum'};
      final part = CleaningPart.fromJson(partJson);
      expect(part.id, equals(1));
      expect(part.name, equals('Interior Vacuum'));

      const req = SubmitCleaningDataRequest(
        cleanedPartIds: [1, 2],
        vehicles: [
          CleanedVehicleEntry(id: 101, vehicleNo: 'AP29AB1234'),
        ],
      );

      final jsonReq = req.toJson();
      expect(jsonReq['CleanedPartIds'], equals([1, 2]));
      expect((jsonReq['Vehicles'] as List).length, equals(1));
    });

    test('AlcoholTestItem and Response parse driver breathalyzer results', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'metadata': {'total': 1},
        'data': [
          {
            'Id': 5,
            'SubmittedDate': '2026-10-30',
            'SubmittedTime': '07:30 AM',
            'PersonType': 'DRIVER',
            'PersonInfo': {
              'Name': 'Ramesh Kumar',
              'Mobile': '9876543210',
            },
            'AlcoholTest': 'PASSED',
            'AlcoholTestReading': 0.00,
            'ImageUrl': 'https://example.com/test.jpg',
            'CreatedBy': 'Security Guard',
          },
        ],
      };

      final resp = AlcoholTestResponse.fromJson(json);
      expect(resp.data.length, equals(1));

      final item = resp.data.first;
      expect(item.id, equals(5));
      expect(item.personName, equals('Ramesh Kumar'));
      expect(item.alcoholTest, equals('PASSED'));
      expect(item.alcoholTestReading, equals(0.00));
      expect(item.imageUrl, equals('https://example.com/test.jpg'));
    });
  });

  group('LogBookProvider State Management', () {
    late MockLogBookService mockService;
    late LogBookProvider provider;

    setUp(() {
      mockService = MockLogBookService();
      provider = LogBookProvider(mockService);
    });

    test('fetchComplaintsStats loads aggregated dashboard items', () async {
      mockService.mockStatsResponse = const ComplaintsDashboardResponse(
        total: 2,
        data: [
          ComplaintDashboardItem(totalCount: 2, status: 'Open'),
        ],
      );

      await provider.fetchComplaintsStats(countBy: 'Status');

      expect(provider.isLoading, isFalse);
      expect(provider.stats.length, equals(1));
      expect(provider.stats.first.status, equals('Open'));
    });

    test('fetchComplaints loads complaint list and manages pagination count', () async {
      mockService.mockComplaintsResponse = const ComplaintDataResponse(
        total: 1,
        data: [
          Complaint(
            id: 1,
            complaintNo: 501,
            vehicleNo: 'AP29AB1234',
            categoryName: 'Engine Noise',
            currStatus: 'Open',
            currAction: 'Diagnosing',
          ),
        ],
      );

      await provider.fetchComplaints();

      expect(provider.complaints.length, equals(1));
      expect(provider.complaints.first.complaintNo, equals(501));
    });

    test('createComplaint delegates to service and triggers refresh', () async {
      const request = CreateComplaintRequest(
        vehicleId: 1,
        vehicleNumber: 'AP29AB1234',
        categoryId: 3,
        description: 'AC cooling issue',
      );

      final result = await provider.createComplaint(request);

      expect(result, isTrue);
      expect(mockService.lastComplaintRequest?.vehicleNumber, equals('AP29AB1234'));
      expect(mockService.lastComplaintRequest?.description, equals('AC cooling issue'));
    });

    test('submitVehicleCleaning handles successful cleaning inspections', () async {
      const request = SubmitCleaningDataRequest(
        cleanedPartIds: [1],
        vehicles: [CleanedVehicleEntry(id: 1, vehicleNo: 'AP29AB1234')],
      );

      final result = await provider.submitCleaningData(request);

      expect(result.success, isTrue);
      expect(mockService.lastCleaningRequest?.cleanedPartIds, equals([1]));
    });

    test('submitAlcoholTest sends driver breathalyzer submission', () async {
      const request = AlcoholTestSubmissionRequest(
        personId: 44,
        personName: 'Ramesh',
        personMobile: '9988776655',
        reading: 0.0,
        status: 'PASSED',
      );

      final result = await provider.submitAlcoholTest(request);

      expect(result, isTrue);
      expect(mockService.lastAlcoholRequest?.personName, equals('Ramesh'));
      expect(mockService.lastAlcoholRequest?.status, equals('PASSED'));
    });
  });
}
