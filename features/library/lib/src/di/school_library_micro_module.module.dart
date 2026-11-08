//@GeneratedMicroModule;SchoolLibraryPackageModule;package:school_library/src/di/school_library_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:routes/routes.dart' as _i678;
import 'package:school_library/src/providers/library_provider.dart' as _i1039;
import 'package:school_library/src/services/library_people_service.dart'
    as _i988;
import 'package:school_library/src/services/library_service.dart' as _i904;
import 'package:school_library/src/services/library_writes.dart' as _i996;

class SchoolLibraryPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i904.LibraryService>(() => _i904.LibraryService());
    gh.lazySingleton<_i996.LibraryWrites>(() => _i996.LibraryWrites());
    gh.lazySingleton<_i988.LibraryPeopleService>(
      () => _i988.LibraryPeopleService(gh<_i678.RouteService>()),
    );
    gh.lazySingleton<_i1039.LibraryProvider>(
      () => _i1039.LibraryProvider(
        gh<_i904.LibraryService>(),
        gh<_i988.LibraryPeopleService>(),
        gh<_i996.LibraryWrites>(),
      ),
    );
  }
}
