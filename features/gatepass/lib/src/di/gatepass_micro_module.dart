import 'package:injectable/injectable.dart';

@InjectableInit.microPackage(
  ignoreUnregisteredTypesInPackages: ['api_client', 'auth'],
)
void initMicroPackage() {}
