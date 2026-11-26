import 'package:api_client/api_client.dart';
import 'package:test/test.dart';

void main() {
  Response<dynamic> responseWith(Object? data) => Response<dynamic>(
    requestOptions: RequestOptions(path: '/v1.0/getThing'),
    statusCode: 200,
    data: data,
  );

  test('returns the parsed value and reports nothing', () {
    var reported = false;
    final client = ApiClient(dio: Dio(), enableLogging: false)
      ..onLogCrash = (_, _, _, {fatal = false, message}) => reported = true;
    final value = client.parse(
      responseWith({'id': 7}),
      (data) => (data as Map<String, dynamic>)['id'] as int,
    );
    expect(value, 7);
    expect(reported, isFalse);
  });

  test('reports the endpoint, shows a message and throws ApiException', () {
    String? reportedPath;
    String? shown;
    final client = ApiClient(dio: Dio(), enableLogging: false);
    client
      ..onLogCrash = (path, _, _, {fatal = false, message}) {
        reportedPath = path;
      }
      ..onShowErrorMessage = (message) {
        shown = message;
      };
    expect(
      () => client.parse(
        responseWith('not a map'),
        (data) => (data as Map<String, dynamic>)['id'] as int,
      ),
      throwsA(isA<UnknownApiException>()),
    );
    expect(reportedPath, '/v1.0/getThing');
    expect(shown, const UnknownApiException().message);
  });
}
