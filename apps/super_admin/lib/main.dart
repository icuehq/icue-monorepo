import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:face_enrollment/face_enrollment.dart';
import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:local_storage/local_storage.dart';
import 'package:provider/provider.dart';
import 'package:super_admin/app_firebase_options.dart';
import 'package:super_admin/di/injection.dart';
import 'package:super_admin/routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = ApiEnvironment.fromEnvironment();
  await initFirebase(firebaseOptionsFor(environment));
  try {
    await configureDependencies(environment.name);

    // Forward unexpected API failures to Crashlytics as non-fatals.
    getIt<ApiClient>().onLogCrash =
        (path, error, stack, {fatal = false, message}) {
          final dio = error is DioException ? error : null;
          CrashlyticsService.instance.recordError(
            error,
            stack,
            reason: 'API ${dio?.requestOptions.method ?? ''} $path: $message',
            information: [
              'status: ${dio?.response?.statusCode}',
              'type: ${dio?.type.name}',
              'url: ${dio?.requestOptions.uri}',
            ],
          );
        };

    // Hive must be open before AuthProvider restores the session from it.
    await getIt<StorageService>().init();
    await getIt<UserLocalStorage>().init();
    await getIt<EmbeddingStore>().init();

    if (Platform.isAndroid) {
      try {
        await getIt<IcueFaceSdk>().initialize();
      } catch (e, stack) {
        debugPrint('Error initializing IcueFaceSdk: $e');
        CrashlyticsService.instance.recordError(
          e,
          stack,
          reason: 'Failed to initialize IcueFaceSdk',
        );
      }
    }
  } catch (error, stack) {
    CrashlyticsService.instance.recordError(
      error,
      stack,
      reason: 'Super Admin startup initialization failed',
    );
    rethrow;
  }

  runApp(SuperAdminApp(authProvider: getIt<AuthProvider>()));
}

class SuperAdminApp extends StatefulWidget {
  const SuperAdminApp({required this.authProvider, super.key});

  final AuthProvider authProvider;

  @override
  State<SuperAdminApp> createState() => _SuperAdminAppState();
}

class _SuperAdminAppState extends State<SuperAdminApp> {
  late final _router = createRouter(widget.authProvider);

  @override
  void initState() {
    super.initState();
    widget.authProvider.addListener(_syncFirebaseUser);
    _syncFirebaseUser();
  }

  void _syncFirebaseUser() {
    final user = widget.authProvider.user;
    final branch = widget.authProvider.selectedBranch;
    CrashlyticsService.instance.setUser(
      id: user == null ? null : '${user.id}',
      organizationId: user == null ? null : '${user.organizationId}',
      zoneId: user == null ? null : '${user.zoneId}',
      branchId: user == null ? null : '${branch?.id ?? user.branchId}',
      schoolName: branch?.schoolName ?? user?.schoolName,
    );
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_syncFirebaseUser);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider(create: (_) => getIt<StudentProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<EmbeddingProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<IdentifyProvider>()),
      ],
      child: MaterialApp.router(
        title: 'iCue Super Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forEnvironment(
          isProd: ApiEnvironment.fromEnvironment().isProd,
        ),
        routerConfig: _router,
      ),
    );
  }
}
