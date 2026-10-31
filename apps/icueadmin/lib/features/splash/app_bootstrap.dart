import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/di/injection.dart';
import 'package:icueadmin/features/splash/splash_page.dart';
import 'package:icueadmin/firebase_options.dart';
import 'package:icueadmin/theme/app_theme.dart';
import 'package:local_storage/local_storage.dart';

/// Shows [SplashPage] while startup tasks run, then builds [builder].
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    required this.environment,
    required this.builder,
    super.key,
  });

  final ApiEnvironment environment;
  final Widget Function(ConnectivityService connectivity) builder;

  /// Upper bound on the store update check so a slow network can't hold the
  /// splash; Play's immediate (blocking) updates take over the UI themselves.
  static const updateCheckTimeout = Duration(seconds: 5);

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<ConnectivityService> _init = _initialize();

  Future<ConnectivityService> _initialize() async {
    await initFirebase(DefaultFirebaseOptions.currentPlatform);
    await configureDependencies(widget.environment.name);

    final connectivity = ConnectivityService();
    await connectivity.init();
    getIt<ApiClient>().isOnline = () => connectivity.isOnline;

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

    // Hive must be open before AuthProvider is created: it restores the
    // session from it, so the router can pick login vs dashboard right away.
    await getIt<StorageService>().init();
    await getIt<UserLocalStorage>().init();
    getIt<AuthProvider>();

    await AppUpdateService.checkForUpdate().timeout(
      AppBootstrap.updateCheckTimeout,
      onTimeout: () {},
    );
    return connectivity;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConnectivityService>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.hasData) return widget.builder(snapshot.data!);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.forEnvironment(widget.environment),
          home: SplashPage(
            error: snapshot.error,
            onRetry: () => setState(() => _init = _initialize()),
          ),
        );
      },
    );
  }
}
