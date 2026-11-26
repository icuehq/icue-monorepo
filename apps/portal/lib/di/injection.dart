import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/inventory.dart';
import 'package:local_storage/local_storage.dart';
import 'package:portal/di/injection.config.dart';
import 'package:routes/routes.dart';
import 'package:school_library/school_library.dart';

final getIt = GetIt.instance;

@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(ApiClientPackageModule),
    ExternalModule(LocalStoragePackageModule),
    ExternalModule(AuthPackageModule),
    ExternalModule(RoutesPackageModule),
    ExternalModule(InventoryPackageModule),
    ExternalModule(SchoolLibraryPackageModule),
  ],
)
Future<void> configureDependencies(String environment) async {
  await getIt.init(environment: environment);
}
