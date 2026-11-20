//@GeneratedMicroModule;FaceEnrollmentPackageModule;package:face_enrollment/src/di/face_enrollment_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:face_enrollment/src/di/face_enrollment_micro_module.dart'
    as _i669;
import 'package:face_enrollment/src/providers/embedding_provider.dart' as _i850;
import 'package:face_enrollment/src/providers/identify_provider.dart' as _i947;
import 'package:face_enrollment/src/providers/student_provider.dart' as _i239;
import 'package:face_enrollment/src/services/student_service.dart' as _i584;
import 'package:face_enrollment/src/storage/embedding_store.dart' as _i421;
import 'package:icue_face_sdk/icue_face_sdk.dart' as _i959;
import 'package:injectable/injectable.dart' as _i526;
import 'package:local_storage/local_storage.dart' as _i486;

class FaceEnrollmentPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    final faceEnrollmentModule = _$FaceEnrollmentModule();
    gh.factory<_i947.IdentifyProvider>(() => _i947.IdentifyProvider());
    gh.lazySingleton<_i959.IcueFaceSdk>(() => faceEnrollmentModule.faceSdk);
    gh.lazySingleton<_i421.EmbeddingStore>(
      () => _i421.EmbeddingStore(gh<_i486.StorageService>()),
    );
    gh.lazySingleton<_i584.StudentService>(
      () => _i584.StudentService(gh<_i633.ApiClient>()),
    );
    gh.factory<_i850.EmbeddingProvider>(
      () => _i850.EmbeddingProvider(
        gh<_i959.IcueFaceSdk>(),
        gh<_i584.StudentService>(),
      ),
    );
    gh.factory<_i239.StudentProvider>(
      () => _i239.StudentProvider(
        gh<_i584.StudentService>(),
        gh<_i421.EmbeddingStore>(),
        gh<_i959.IcueFaceSdk>(),
      ),
    );
  }
}

class _$FaceEnrollmentModule extends _i669.FaceEnrollmentModule {}
