import 'package:api_client/src/client/api_client.dart';
import 'package:injectable/injectable.dart';

@microPackageInit
void initMicroPackage() {}

/// Injectable module that registers the centralized [ApiClient] singleton.
@module
abstract class ApiClientModule {
  @lazySingleton
  ApiClient apiClient() {
    return ApiClient();
  }
}
