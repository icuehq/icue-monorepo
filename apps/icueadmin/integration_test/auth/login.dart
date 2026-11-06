import 'package:flutter_test/flutter_test.dart';

import '../support/driver.dart';

/// Test account for the dev backend, given at run time so no phone number or code is stored in the repository:
/// `--dart-define=TEST_PHONE=<mobile number> --dart-define=TEST_OTP=<otp>`.
const _phone = String.fromEnvironment('TEST_PHONE');
const _otp = String.fromEnvironment('TEST_OTP');

/// Signs in through the real login screens when the app opens on them (no stored session, or it expired). When the
/// Dashboard is already showing there is nothing to do.
Future<void> loginSteps(WidgetTester tester) async {
  await step(tester, '0 login', () async {
    if (await appears(
      tester,
      find.textContaining('Welcome back'),
      wait: 1500,
    )) {
      return;
    }
    if (_phone.isEmpty || _otp.isEmpty) {
      throw TestFailure(
        'The app is on the login screen: pass --dart-define=TEST_PHONE=... --dart-define=TEST_OTP=... or sign in on the device first.',
      );
    }
    await waitFor(tester, find.text('Generate OTP'));
    await fill(tester, 'Enter Mobile Number', _phone);
    await tapText(tester, 'Generate OTP');
    await waitFor(tester, find.text('Verify & Login'), timeout: 30);
    await fill(tester, 'Enter OTP', _otp);
    await tapText(tester, 'Verify & Login');
    await waitFor(tester, find.textContaining('Welcome back'), timeout: 60);
  });
}
