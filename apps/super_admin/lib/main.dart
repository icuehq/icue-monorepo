import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:face_enrollment/face_enrollment.dart';
import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:local_storage/local_storage.dart';
import 'package:provider/provider.dart';
import 'package:super_admin/di/injection.dart';
import 'package:super_admin/routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(ApiEnvironment.fromEnvironment().name);

  // Hive must be open before AuthProvider restores the session from it.
  await getIt<StorageService>().init();
  await getIt<UserLocalStorage>().init();
  await getIt<EmbeddingStore>().init();

  if (Platform.isAndroid) {
    try {
      await getIt<IcueFaceSdk>().initialize();
    } catch (e) {
      debugPrint('Error initializing IcueFaceSdk: $e');
    }
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
  void dispose() {
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
