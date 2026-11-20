//@GeneratedMicroModule;MessMealsPackageModule;package:mess_meals/src/di/mess_meals_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:auth/auth.dart' as _i662;
import 'package:injectable/injectable.dart' as _i526;
import 'package:mess_meals/src/providers/meals_provider.dart' as _i189;
import 'package:mess_meals/src/services/mess_meals_service.dart' as _i91;

class MessMealsPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i91.MessMealsService>(
      () => _i91.MessMealsService(gh<_i633.ApiClient>()),
    );
    gh.lazySingleton<_i189.MealsProvider>(
      () => _i189.MealsProvider(
        gh<_i91.MessMealsService>(),
        gh<_i662.ParentAuthProvider>(),
      ),
    );
  }
}
