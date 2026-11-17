import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:safehands/src/models/escort.dart';
import 'package:safehands/src/models/safehands_pin.dart';
import 'package:safehands/src/services/safehands_service.dart';

class _FakeApiClient extends Fake implements ApiClient {
  dynamic body;
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
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  test('createPin takes the first item of the list', () async {
    final api = _FakeApiClient()
      ..body = [
        {'PIN': 4821, 'Heading': 'Show this PIN'},
      ];
    final pin = await SafeHandsService(api)
        .createPin(studentId: 1, studentName: 'Asha', admissionNumber: 'A-1');
    expect(pin?.pin, 4821);
    expect(api.lastPath, '/v1.0/CreateSafeHandsToken');
    expect(api.lastData, {
      'StudentId': 1,
      'StudentName': 'Asha',
      'AdmissionNumber': 'A-1',
    });
  });

  test('getPin returns null for the empty object the server sends', () async {
    final api = _FakeApiClient()..body = <String, dynamic>{};
    expect(await SafeHandsService(api).getPin(1), isNull);
    api.body = {'PIN': 7, 'Heading': 'h'};
    expect((await SafeHandsService(api).getPin(1))?.pin, 7);
  });

  test('Escort parses numeric mobile and temporary type', () {
    final escort = Escort.fromJson({
      'Id': 3,
      'Type': 'TEMPORARY',
      'Name': 'Ravi',
      'Relation': 'Uncle',
      'Mobile': 9876543210,
      'PhotoUrl': 'https://x/p.jpg',
      'FromDate': '01/03/2026',
      'ToDate': '05/03/2026',
    });
    expect(escort.mobile, '9876543210');
    expect(escort.isTemporary, isTrue);
    expect(SafeHandsPin.fromJson({'PIN': 1, 'Heading': ''}).pin, 1);
  });

  test(
    'saveEscort sends the legacy form keys and dates only when temporary',
    () async {
      final api = _FakeApiClient()..body = {'err': false};
      final service = SafeHandsService(api);
      const photo = IcuePickedFile(name: 'p.jpg', bytes: [1, 2, 3]);

      var result = await service.saveEscort(
        studentId: 1,
        studentMobile: '9000000000',
        type: escortTemporary,
        name: 'Ravi',
        relation: 'Uncle',
        escortMobile: '9876543210',
        photo: photo,
        fromDate: DateTime(2026, 3),
        toDate: DateTime(2026, 3, 5),
      );
      expect(result.ok, isTrue);
      var fields = {
        for (final f in (api.lastData as FormData).fields) f.key: f.value,
      };
      expect(fields['Source'], 'adminapp');
      expect(fields['EscMobile'], '9876543210');
      expect(fields['FromDate'], '03/01/2026');
      expect(fields['ToDate'], '03/05/2026');
      expect((api.lastData as FormData).files.single.key, 'Photo');

      api.body = {'err': true, 'message': 'Duplicate'};
      result = await service.saveEscort(
        studentId: 1,
        studentMobile: null,
        type: escortPermanent,
        name: 'Ravi',
        relation: 'Uncle',
        escortMobile: '9876543210',
        photo: photo,
      );
      expect(result.ok, isFalse);
      expect(result.message, 'Duplicate');
      fields = {
        for (final f in (api.lastData as FormData).fields) f.key: f.value,
      };
      expect(fields.containsKey('FromDate'), isFalse);
    },
  );
}
