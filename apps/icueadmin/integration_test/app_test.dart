import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'auth/login.dart';
import 'inventory/masters.dart';
import 'inventory/procurement.dart';
import 'inventory/stock.dart';
import 'support/driver.dart';

/// The whole e2e suite in guide order, in ONE app run (the app builds and starts once). Steps share the emulator
/// data and each depends on the earlier ones; a failing step is reported and the run goes on.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('inventory and library', (tester) async {
    await startApp(tester);
    await loginSteps(tester);
    await mastersSteps(tester);
    await stockSteps(tester);
    await procurementSteps(tester);
    finish();
  }, timeout: const Timeout(Duration(minutes: 40)));
}
