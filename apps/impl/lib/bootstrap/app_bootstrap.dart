import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:impl/app_firebase_options.dart';
import 'package:impl/bootstrap/splash_page.dart';
import 'package:impl/di/injection.dart';
import 'package:impl/routing/app_navigator.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_storage/local_storage.dart';

/// `Source` value the parent endpoints expect on every request.
const _parentSource = 'parentapp';

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
    final connectivity = IcueConnectivityService();
    await Future.wait([
      initFirebase(firebaseOptionsFor(widget.environment)),
      _initLocalStorage(),
      connectivity.init(),
      initializeDateFormatting('en_IN'),
    ]);

    final apiClient = getIt<ApiClient>()
      ..source = _parentSource
      ..isOnline = (() => connectivity.isOnline)
      ..setTokenProvider(getIt<ParentTokenProvider>())
      // API failures (4xx/5xx, offline) show as a toast over the current page.
      ..onShowErrorMessage = (message) {
        final overlay = rootNavigatorKey.currentState?.overlay;
        if (overlay != null) IcueToast.error(overlay.context, message);
      }
      // Forward unexpected API failures to Crashlytics as non-fatals.
      ..onLogCrash = (path, error, stack, {fatal = false, message}) {
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
    // A 401 clears the session; the router then redirects to login.
    getIt<ParentTokenProvider>().onSessionExpired = () =>
        unawaited(getIt<ParentAuthProvider>().clearSession());
    assert(apiClient.source == _parentSource);

    await getIt<ParentDeviceInfo>().load();
    await IcueAppUpdateService.checkForUpdate().timeout(
      AppBootstrap.updateCheckTimeout,
      onTimeout: () {},
    );
    return connectivity;
  }

  /// Hive must be open before the session is restored so the router can pick
  /// login vs home right away.
  Future<void> _initLocalStorage() async {
    await configureDependencies(widget.environment.name);
    await getIt<StorageService>().init();
    await getIt<ParentSessionStorage>().init();
    getIt<ParentAuthProvider>().restore();
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
          home: SplashPage(
            error: snapshot.error,
            onRetry: () => setState(() {
              _init = _initialize();
            }),
          ),
        );
      },
    );
  }
}
