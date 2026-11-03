import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart' show HttpClientAdapter, ResponseBody;
import 'package:test/test.dart';

void main() {
  test('fails fast with NetworkException while offline', () async {
    var hit = false;
    final dio = Dio()..httpClientAdapter = _Adapter(() => hit = true);
    final client = ApiClient(dio: dio, enableLogging: false)
      ..isOnline = () => false;
    await expectLater(
      client.dio.get<dynamic>('https://example.invalid/x'),
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'error',
          isA<NetworkException>(),
        ),
      ),
    );
    expect(hit, isFalse);
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.onFetch);
  final void Function() onFetch;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? s,
    Future<void>? c,
  ) async {
    onFetch();
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
