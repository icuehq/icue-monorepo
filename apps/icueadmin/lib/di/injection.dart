import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:get_it/get_it.dart';
import 'package:icueadmin/di/injection.config.dart';
import 'package:injectable/injectable.dart';
import 'package:local_storage/local_storage.dart';

final getIt = GetIt.instance;

@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(ApiClientPackageModule),
    ExternalModule(LocalStoragePackageModule),
    ExternalModule(AuthPackageModule),
  ],
)
Future<void> configureDependencies(String environment) async {
  await getIt.init(environment: environment);
}
