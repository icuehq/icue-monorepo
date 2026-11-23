import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends Fake implements ApiClient {
  @override
  T parse<T>(Response<dynamic> response, T Function(dynamic data) fromJson) =>
      fromJson(response.data);

  int status = 200;
  dynamic body;
  String? lastPath;
  dynamic lastData;
  Options? lastOptions;

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
    lastOptions = options;
    return Response<T>(
      data: body as T,
      statusCode: status,
      requestOptions: RequestOptions(path: path),
    );
  }
}

class _FakeDeviceInfo extends Fake implements ParentDeviceInfo {
  @override
  Map<String, dynamic> get json => <String, dynamic>{'osname': 'Android'};
}

Map<String, dynamic> _studentJson({bool showClassSection = true}) =>
    <String, dynamic>{
      'OrganizationId': 1,
      'BranchId': 2,
      'ZoneId': 3,
      'Id': 10,
      'Name': 'Asha',
      'AdmissionNumber': 'A-1',
      'ClassId': 5,
      'Standard': '6',
      'Section': 'B',
      'Gender': 'F',
      'Roles': <dynamic>[
        <String, dynamic>{'Id': 1, 'Name': 'Parent'},
      ],
      'ParentAppFeature': <String, dynamic>{'Id': 2, 'Name': 'Full'},
      'PickCoordinates': <dynamic>[12, 77.5],
      'ShowClsSec': showClassSection,
    };

void main() {
  group('ParentUser', () {
    test('parses students and survives a toJson round trip', () {
      final user = ParentUser.fromJson(<String, dynamic>{
        'Id': 7,
        'Token': 't',
        'Students': <dynamic>[_studentJson()],
      });
      expect(user.token, 't');
      final student = user.students.single;
      expect(student.name, 'Asha');
      expect(student.pickCoordinates, <double>[12, 77.5]);
      expect(student.classSection, '6 - B');

      final again = ParentStudent.fromJson(student.toJson());
      expect(again.toJson(), student.toJson());
    });

    test('classSection is null when the school hides it', () {
      final student = ParentStudent.fromJson(
        _studentJson(showClassSection: false),
      );
      expect(student.classSection, isNull);
    });
  });

  group('ParentAuthService', () {
    late _FakeApiClient api;
    late ParentAuthService service;

    setUp(() {
      api = _FakeApiClient();
      service = ParentAuthService(api, _FakeDeviceInfo());
    });

    test('generateOtp maps 204 to notRegistered', () async {
      api
        ..status = 204
        ..body = null;
      final outcome = await service.generateOtp('9876543210');
      expect(outcome.result, ParentOtpResult.notRegistered);
      expect(api.lastPath, '/v1.0/generateOtp');
    });

    test('generateOtp returns the server message on 200', () async {
      api.body = <String, dynamic>{'message': 'OTP sent'};
      final outcome = await service.generateOtp('9876543210');
      expect(outcome.result, ParentOtpResult.sent);
      expect(outcome.message, 'OTP sent');
      expect(api.lastOptions?.extra?['no_auth'], isTrue);
    });

    test('login posts username, otp and device info', () async {
      api.body = <String, dynamic>{
        'Id': 7,
        'Token': 't',
        'Students': <dynamic>[],
      };
      final user = await service.login('9876543210', '1234');
      expect(user.id, 7);
      expect(api.lastPath, '/v1.0/parentLogin');
      expect(api.lastData, <String, dynamic>{
        'username': '9876543210',
        'password': '1234',
        'osname': 'Android',
      });
    });
  });
}
