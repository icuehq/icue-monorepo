// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:icue_sdk/src/providers/notifications_provider.dart' as _i121;
import 'package:icue_sdk/src/providers/user_provider.dart' as _i560;
import 'package:icue_sdk/src/providers/vehicle_provider.dart' as _i327;
import 'package:icue_sdk/src/services/device_info_service.dart' as _i579;
import 'package:icue_sdk/src/services/networking/api_client.dart' as _i879;
import 'package:icue_sdk/src/services/notification_service.dart' as _i664;
import 'package:icue_sdk/src/services/session.dart' as _i627;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    gh.singleton<_i579.DeviceInfoService>(() => _i579.DeviceInfoService());
    gh.singleton<_i627.SessionService>(() => _i627.SessionService());
    gh.lazySingleton<_i879.ApiClient>(
        () => _i879.ApiClient(gh<_i627.SessionService>()));
    gh.lazySingleton<_i327.VehicleProvider>(() => _i327.VehicleProvider(
          apiClient: gh<_i879.ApiClient>(),
          deviceInfoService: gh<_i579.DeviceInfoService>(),
        ));
    gh.lazySingleton<_i121.NotificationsProvider>(
        () => _i121.NotificationsProvider(gh<_i879.ApiClient>()));
    gh.lazySingleton<_i560.UserProvider>(() => _i560.UserProvider(
          gh<_i627.SessionService>(),
          apiClient: gh<_i879.ApiClient>(),
          deviceInfoService: gh<_i579.DeviceInfoService>(),
        ));
    gh.singleton<_i664.NotificationService>(() => _i664.NotificationService(
          userProvider: gh<_i560.UserProvider>(),
          vehicleProvider: gh<_i327.VehicleProvider>(),
          sessionService: gh<_i627.SessionService>(),
        ));
    return this;
  }
}
