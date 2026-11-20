import 'package:announcements/announcements.dart';
import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:gatepass/gatepass.dart';
import 'package:get_it/get_it.dart';
import 'package:impl/di/injection.config.dart';
import 'package:injectable/injectable.dart';
import 'package:local_storage/local_storage.dart';
import 'package:mess_meals/mess_meals.dart';
import 'package:parent_transport/parent_transport.dart';
import 'package:safehands/safehands.dart';
import 'package:school_connect/school_connect.dart';
import 'package:students/students.dart';

final getIt = GetIt.instance;

@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(ApiClientPackageModule),
    ExternalModule(LocalStoragePackageModule),
    ExternalModule(AuthPackageModule),
    ExternalModule(StudentsPackageModule),
    ExternalModule(AnnouncementsPackageModule),
    ExternalModule(GatepassPackageModule),
    ExternalModule(ParentTransportPackageModule),
    ExternalModule(MessMealsPackageModule),
    ExternalModule(SafehandsPackageModule),
    ExternalModule(SchoolConnectPackageModule),
  ],
)
Future<void> configureDependencies(String environment) async {
  await getIt.init(environment: environment);
}
