import 'package:announcements/announcements.dart';
import 'package:api_client/api_client.dart';
import 'package:attendance/attendance.dart';
import 'package:auth/auth.dart';
import 'package:drivers/drivers.dart';
import 'package:drop_boarding/drop_boarding.dart';
import 'package:expenses/expenses.dart';
import 'package:gatepass/gatepass.dart';
import 'package:get_it/get_it.dart';
import 'package:icueadmin/di/injection.config.dart';
import 'package:injectable/injectable.dart';
import 'package:local_storage/local_storage.dart';
import 'package:logbook/logbook.dart';
import 'package:reports/reports.dart';
import 'package:routes/routes.dart';
import 'package:tracking/tracking.dart';
import 'package:vehicles/vehicles.dart';

final getIt = GetIt.instance;

@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(ApiClientPackageModule),
    ExternalModule(LocalStoragePackageModule),
    ExternalModule(AuthPackageModule),
    ExternalModule(DriversPackageModule),
    ExternalModule(VehiclesPackageModule),
    ExternalModule(RoutesPackageModule),
    ExternalModule(AnnouncementsPackageModule),
    ExternalModule(AttendancePackageModule),
    ExternalModule(DropBoardingPackageModule),
    ExternalModule(ExpensesPackageModule),
    ExternalModule(GatepassPackageModule),
    ExternalModule(LogbookPackageModule),
    ExternalModule(ReportsPackageModule),
    ExternalModule(TrackingPackageModule),
  ],
)
Future<void> configureDependencies(String environment) async {
  await getIt.init(environment: environment);
}
