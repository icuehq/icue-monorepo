import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:students/students.dart';

class _FakeApiClient extends Fake implements ApiClient {
  @override
  T parse<T>(Response<dynamic> response, T Function(dynamic data) fromJson) =>
      fromJson(response.data);

  dynamic body;
  Object? lastData;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    lastData = data;
    return Response<T>(
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

Map<String, dynamic> _action(
  int id,
  num order, {
  bool? sub,
  List<dynamic>? items,
}) => <String, dynamic>{
  'Id': id,
  'Name': 'n$id',
  'RouteState': 'layout.x$id',
  'Icon': 'https://x/$id.svg',
  'TabOrder': order,
  'DisplayName': 'Action $id',
  'Colors': <dynamic>['0xFF000000', '0xFFFFFFFF'],
  'SubActions': sub,
  'SubActionItems': items,
};

void main() {
  test('getRoleActions sorts by TabOrder and sends the student id', () async {
    final api = _FakeApiClient()
      ..body = <dynamic>[_action(1, 3), _action(2, 1), _action(3, 2)];
    final actions = await StudentsService(api).getRoleActions(42);
    expect(actions.map((a) => a.id), <int>[2, 3, 1]);
    expect(api.lastData, <String, dynamic>{'StudentId': 42});
  });

  test('an action with sub-actions but none sent is hidden', () {
    final hidden = ParentRoleAction.fromJson(
      _action(1, 1, sub: true, items: <dynamic>[]),
    );
    final shown = ParentRoleAction.fromJson(_action(2, 1));
    expect(hidden.isVisible, isFalse);
    expect(shown.isVisible, isTrue);
  });

  test('getLinkUrl returns null when the server flags an error', () async {
    final api = _FakeApiClient()
      ..body = <String, dynamic>{'err': true, 'linkUrl': 'https://x'};
    expect(await StudentsService(api).getLinkUrl(1, 'mess'), isNull);
    api.body = <String, dynamic>{'err': false, 'linkUrl': 'https://x'};
    expect(await StudentsService(api).getLinkUrl(1, 'mess'), 'https://x');
  });
}
