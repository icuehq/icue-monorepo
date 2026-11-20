// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:announcements/announcements.dart' as _i967;
import 'package:api_client/api_client.dart' as _i633;
import 'package:auth/auth.dart' as _i662;
import 'package:gatepass/gatepass.dart' as _i973;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:local_storage/local_storage.dart' as _i486;
import 'package:mess_meals/mess_meals.dart' as _i503;
import 'package:parent_transport/parent_transport.dart' as _i844;
import 'package:safehands/safehands.dart' as _i816;
import 'package:school_connect/school_connect.dart' as _i528;
import 'package:students/students.dart' as _i224;

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
    await _i224.StudentsPackageModule().init(gh);
    await _i967.AnnouncementsPackageModule().init(gh);
    await _i973.GatepassPackageModule().init(gh);
    await _i844.ParentTransportPackageModule().init(gh);
    await _i503.MessMealsPackageModule().init(gh);
    await _i816.SafehandsPackageModule().init(gh);
    await _i528.SchoolConnectPackageModule().init(gh);
    return this;
  }
}
