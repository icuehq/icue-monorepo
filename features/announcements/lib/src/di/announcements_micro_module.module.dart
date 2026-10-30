//@GeneratedMicroModule;AnnouncementsPackageModule;package:announcements/src/di/announcements_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:announcements/src/providers/announcements_provider.dart'
    as _i739;
import 'package:announcements/src/services/announcement_service.dart' as _i60;
import 'package:api_client/api_client.dart' as _i633;
import 'package:injectable/injectable.dart' as _i526;

class AnnouncementsPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i60.AnnouncementService>(
        () => _i60.AnnouncementService(gh<_i633.ApiClient>()));
    gh.lazySingleton<_i739.AnnouncementsProvider>(
        () => _i739.AnnouncementsProvider(gh<_i60.AnnouncementService>()));
  }
}
