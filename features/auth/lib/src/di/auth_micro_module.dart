import 'package:injectable/injectable.dart';

@InjectableInit.microPackage(
  ignoreUnregisteredTypesInPackages: ['api_client', 'local_storage'],
)
void initMicroPackage() {}
