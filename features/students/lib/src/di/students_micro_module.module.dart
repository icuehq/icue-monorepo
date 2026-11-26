//@GeneratedMicroModule;StudentsPackageModule;package:students/src/di/students_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:auth/auth.dart' as _i662;
import 'package:injectable/injectable.dart' as _i526;
import 'package:students/src/providers/parent_students_provider.dart' as _i635;
import 'package:students/src/services/students_service.dart' as _i1044;

class StudentsPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i1044.StudentsService>(
      () => _i1044.StudentsService(gh<_i633.ApiClient>()),
    );
    gh.lazySingleton<_i635.ParentStudentsProvider>(
      () => _i635.ParentStudentsProvider(
        gh<_i1044.StudentsService>(),
        gh<_i662.ParentAuthProvider>(),
      ),
    );
  }
}
