import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:drivers/drivers.dart';
import 'package:get_it/get_it.dart';
import 'package:icueadmin/di/injection.config.dart';
import 'package:injectable/injectable.dart';
import 'package:local_storage/local_storage.dart';
import 'package:routes/routes.dart';
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
  ],
)
Future<void> configureDependencies(String environment) async {
  await getIt.init(environment: environment);
}
