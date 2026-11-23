import 'package:api_client/api_client.dart';
import 'package:test/test.dart';

void main() {
  test('forwards errors to the reporter but skips ApiException', () {
    final reported = <String?>[];
    errorReporter = (error, stack, where) => reported.add(where);
    addTearDown(() => errorReporter = null);

    reportError(StateError('x'), null, 'Where.it.broke');
    reportError(const NetworkException(), null, 'Skipped');

    expect(reported, ['Where.it.broke']);
  });
}
