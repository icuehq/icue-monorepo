import 'package:api_client/src/auth/token_provider.dart';
import 'package:api_client/src/client/api_client.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

@microPackageInit
void initMicroPackage() {}

/// Injectable module that registers the centralized [ApiClient] singleton.
@module
abstract class ApiClientModule {
  @lazySingleton
  ApiClient apiClient() {
    return ApiClient(
      tokenProvider: GetIt.I.isRegistered<TokenProvider>()
          ? GetIt.I<TokenProvider>()
          : null,
    );
  }
}
