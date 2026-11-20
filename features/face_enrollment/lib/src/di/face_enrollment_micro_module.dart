import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:injectable/injectable.dart';

@InjectableInit.microPackage(
  ignoreUnregisteredTypesInPackages: ['api_client', 'local_storage'],
)
void initMicroPackage() {}

@module
abstract class FaceEnrollmentModule {
  @lazySingleton
  IcueFaceSdk get faceSdk => IcueFaceSdk();
}
