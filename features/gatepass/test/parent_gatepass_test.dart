import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatepass/gatepass.dart';

class _FakeApiClient extends Fake implements ApiClient {
  dynamic body;
  String? lastPath;
  Map<String, dynamic>? lastData;

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
    lastData = data as Map<String, dynamic>?;
    return Response<T>(
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  test('request sends the US date and treats err:true as refused', () async {
    final api = _FakeApiClient()
      ..body = <String, dynamic>{'err': true, 'message': 'Already requested'};
    final result = await ParentGatePassService(
      api,
    ).request(studentId: 5, category: 'MEDICAL', today: DateTime(2026, 3, 7));
    expect(result.ok, isFalse);
    expect(result.message, 'Already requested');
    expect(api.lastData, <String, dynamic>{
      'StudentId': 5,
      'PersonId': 5,
      'GatePassDate': '03/07/2026',
      'GatePassType': 'MEDICAL',
    });
  });

  test('getRequests sends the period and parses the list', () async {
    final api = _FakeApiClient()
      ..body = <String, dynamic>{
        'data': [
          {
            'Id': 1,
            'GatePassType': 'MEDICAL',
            'Status': 'Approved',
            'StatusDt': '2026-03-07 10:00:00',
          },
        ],
      };
    final list = await ParentGatePassService(api).getRequests(
      studentId: 5,
      from: DateTime(2026, 3),
      to: DateTime(2026, 3, 7),
    );
    expect(list.single.status, 'Approved');
    expect(api.lastData?['FromDate'], '03/01/2026');
    expect(api.lastData?['ToDate'], '03/07/2026');
    expect(api.lastPath, '/v1.0/getStuGatePass');
  });
}
