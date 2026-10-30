import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatepass/gatepass.dart';

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
  group('GatePass Models Serialization', () {
    test('GatePassType and Response deserialize and serialize properly', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'data': [
          {'Id': 1, 'Category': 'MEDICAL', 'DisplayName': 'Medical Leave'},
          {'Id': 2, 'Category': 'PERSONAL', 'DisplayName': 'Personal Leave'},
        ],
      };

      final response = GatePassTypesResponse.fromJson(json);
      expect(response.err, false);
      expect(response.data.length, 2);
      expect(response.data.first.id, 1);
      expect(response.data.first.category, 'MEDICAL');
      expect(response.data.first.displayName, 'Medical Leave');

      final out = response.toJson();
      expect((out['data'] as List).length, 2);
    });

    test('GatePassRequest and Response deserialize properly', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'data': [
          {
            'Id': 101,
            'OrganizationId': 1,
            'BranchId': 2,
            'ZoneId': 3,
            'PersonType': 'STUDENT',
            'GatePassType': 'MEDICAL',
            'Class': 'X',
            'Section': 'A',
            'AdmissionNumber': 'ADM-2026',
            'Name': 'Alice Smith',
            'PersonId': 5001,
            'IsHostelite': false,
            'HostelType': 'DayScholar',
            'RequestDate': '2026-10-30',
            'RequestTime': '10:30 AM',
            'RequestDt': '2026-10-30',
          }
        ],
      };

      final response = GatePassRequestsResponse.fromJson(json);
      expect(response.data.length, 1);
      final req = response.data.first;
      expect(req.id, 101);
      expect(req.name, 'Alice Smith');
      expect(req.datumClass, 'X');
      expect(req.admissionNumber, 'ADM-2026');

      final out = req.toJson();
      expect(out['Class'], 'X');
      expect(out['UniqueNo'], isNull); // in GatePassRequest it's AdmissionNumber
      expect(out['AdmissionNumber'], 'ADM-2026');
    });

    test('CreateGatePassRequest serializes into exact API payload', () {
      const request = CreateGatePassRequest(
        personId: 5001,
        name: 'Alice Smith',
        classId: 10,
        className: 'X',
        section: 'A',
        admissionNumber: 'ADM-2026',
        gatePassDate: '2026-10-30',
        gatePassType: 'MEDICAL',
      );

      final json = request.toJson();
      expect(json['PersonId'], 5001);
      expect(json['Name'], 'Alice Smith');
      expect(json['ClassId'], 10);
      expect(json['Class'], 'X');
      expect(json['Section'], 'A');
      expect(json['UniqueNo'], 'ADM-2026');
      expect(json['GatePassDate'], '2026-10-30');
      expect(json['GatePassType'], 'MEDICAL');
      expect(json['PersonType'], 'STUDENT');
    });
  });

  group('GatePassProvider State Management', () {
    late MockApiClient mockApi;
    late GatePassService service;
    late GatePassProvider provider;

    setUp(() {
      mockApi = MockApiClient();
      service = GatePassService(mockApi);
      provider = GatePassProvider(service);
    });

    test('fetchGatePassTypes loads types and caches them', () async {
      mockApi.nextResponseData = {
        'err': false,
        'message': 'Success',
        'data': [
          {'Id': 1, 'Category': 'DAY_OUT', 'DisplayName': 'Day Out'},
        ],
      };

      await provider.fetchGatePassTypes();

      expect(mockApi.lastPath, '/v1.0/getGatePassTypes');
      expect(provider.gatepassTypes.length, 1);
      expect(provider.gatepassTypes.first.category, 'DAY_OUT');

      // Second call should use cache without hitting API
      mockApi.lastPath = null;
      await provider.fetchGatePassTypes();
      expect(mockApi.lastPath, isNull);
    });

    test('fetchGatePassRequests loads pending requests for date', () async {
      mockApi.nextResponseData = {
        'err': false,
        'message': 'Success',
        'data': [
          {
            'Id': 202,
            'OrganizationId': 1,
            'BranchId': 2,
            'ZoneId': 3,
            'PersonType': 'STUDENT',
            'GatePassType': 'MEDICAL',
            'Class': 'IX',
            'Section': 'B',
            'AdmissionNumber': 'ADM-99',
            'Name': 'Bob Jones',
            'PersonId': 6002,
            'IsHostelite': false,
            'HostelType': 'DayScholar',
            'RequestDate': '2026-10-30',
            'RequestTime': '11:00 AM',
            'RequestDt': '2026-10-30',
          }
        ],
      };

      await provider.fetchGatePassRequests(DateTime(2026, 10, 30));

      expect(mockApi.lastPath, '/v1.0/getRequestedGatePass');
      expect((mockApi.lastData as Map)['Date'], '2026-10-30');
      expect(provider.requests.length, 1);
      expect(provider.requests.first.name, 'Bob Jones');
    });

    test('issueGatePass delegates to service and returns success', () async {
      mockApi.nextResponseData = {'err': false, 'message': 'Created'};

      const req = CreateGatePassRequest(
        personId: 7001,
        name: 'Charlie',
        gatePassType: 'OUTING',
      );

      final success = await provider.issueGatePass(req);

      expect(mockApi.lastPath, '/v1.0/createGatePass');
      expect(success, true);
      expect(provider.isLoading, false);
    });

    test('updateGatePassStatus removes approved item from pending list', () async {
      mockApi.nextResponseData = {
        'err': false,
        'message': 'Success',
        'data': [
          {
            'Id': 303,
            'OrganizationId': 1,
            'BranchId': 2,
            'ZoneId': 3,
            'PersonType': 'STUDENT',
            'GatePassType': 'MEDICAL',
            'Class': 'X',
            'Section': 'A',
            'AdmissionNumber': 'ADM-303',
            'Name': 'David',
            'PersonId': 8003,
            'IsHostelite': false,
            'HostelType': 'InCampus',
            'RequestDate': '2026-10-30',
            'RequestTime': '09:00 AM',
            'RequestDt': '2026-10-30',
          }
        ],
      };

      await provider.fetchGatePassRequests(DateTime(2026, 10, 30));
      expect(provider.requests.length, 1);

      mockApi.nextResponseData = {'err': false, 'message': 'Approved'};
      final success = await provider.updateGatePassStatus(
        id: 303,
        personId: 8003,
        date: '2026-10-30',
        status: 'APPROVE',
      );

      expect(mockApi.lastPath, '/v1.0/approveGPRequest');
      expect(success, true);
      expect(provider.requests, isEmpty);
    });

    test('clearData empties requests and resets error message', () {
      provider.clearData();
      expect(provider.requests, isEmpty);
      expect(provider.errorMessage, isNull);
    });
  });
}
