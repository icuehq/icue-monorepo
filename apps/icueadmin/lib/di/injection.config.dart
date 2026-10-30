// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:api_client/api_client.dart' as _i633;
import 'package:auth/auth.dart' as _i662;
import 'package:drivers/drivers.dart' as _i359;
import 'package:get_it/get_it.dart' as _i174;
import 'package:icueadmin/features/home/home_view_model.dart' as _i717;
import 'package:injectable/injectable.dart' as _i526;
import 'package:local_storage/local_storage.dart' as _i486;
import 'package:routes/routes.dart' as _i678;
import 'package:vehicles/vehicles.dart' as _i107;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    await _i633.ApiClientPackageModule().init(gh);
    await _i486.LocalStoragePackageModule().init(gh);
    await _i662.AuthPackageModule().init(gh);
    await _i359.DriversPackageModule().init(gh);
    await _i107.VehiclesPackageModule().init(gh);
    await _i678.RoutesPackageModule().init(gh);
    gh.factory<_i717.HomeViewModel>(
      () => _i717.HomeViewModel(gh<_i633.ApiClient>()),
    );
    return this;
  }
}
