// Package imports:
import 'package:dio/dio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'base_api_client.dart';
import 'injectable.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  preferRelativeImports: true, // default
)
void configureDependencies() => getIt.init();

@module
abstract class ServiceModules {
  @singleton
  Dio get dio => BaseApiClient.createDio();

  @lazySingleton
  FirebaseAnalytics get firebaseAnalytics => FirebaseAnalytics.instance;

  @lazySingleton
  FirebaseCrashlytics get firebaseCrashlytics => FirebaseCrashlytics.instance;

  @lazySingleton
  FirebaseMessaging get firebaseMessaging => FirebaseMessaging.instance;
}
