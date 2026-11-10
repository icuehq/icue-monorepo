import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:icueadmin/app_firebase_options.dart';
import 'package:icueadmin/di/injection.dart';
import 'package:icueadmin/features/splash/splash_page.dart';
import 'package:local_storage/local_storage.dart';

/// Shows [SplashPage] while startup tasks run, then builds [builder].
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    required this.environment,
    required this.builder,
    super.key,
  });

  final ApiEnvironment environment;
  final Widget Function(IcueConnectivityService connectivity) builder;

  /// Upper bound on the store update check so a slow network can't hold the
  /// splash; Play's immediate (blocking) updates take over the UI themselves.
  static const updateCheckTimeout = Duration(seconds: 5);

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<IcueConnectivityService> _init = _initialize();

  Future<IcueConnectivityService> _initialize() async {
    await initFirebase(firebaseOptionsFor(widget.environment));
    await configureDependencies(widget.environment.name);

    final connectivity = IcueConnectivityService();
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

    await IcueAppUpdateService.checkForUpdate().timeout(
      AppBootstrap.updateCheckTimeout,
      onTimeout: () {},
    );
    return connectivity;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IcueConnectivityService>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.hasData) return widget.builder(snapshot.data!);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: IcueTheme.forEnvironment(isProd: widget.environment.isProd),
          // Always show the splash, whatever URL the browser opened on
          // (e.g. /login), which this router-less app has no route for.
          onGenerateInitialRoutes: (_) => [
            MaterialPageRoute<void>(
              builder: (_) => SplashPage(
                error: snapshot.error,
                onRetry: () => setState(() {
                  _init = _initialize();
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}
