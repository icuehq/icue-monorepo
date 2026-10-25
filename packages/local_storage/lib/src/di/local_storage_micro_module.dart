import 'package:injectable/injectable.dart';
import 'package:local_storage/src/service/hive_storage_service.dart';
import 'package:local_storage/src/service/storage_service.dart';

@InjectableInit.microPackage()
void initMicroPackage() {}

@module
abstract class LocalStorageModule {
  @lazySingleton
  StorageService storageService(HiveStorageService service) => service;
}
