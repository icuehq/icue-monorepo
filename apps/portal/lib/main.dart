import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:local_storage/local_storage.dart';
import 'package:portal/app_firebase_options.dart';
import 'package:portal/di/injection.dart';
import 'package:portal/routing/app_router.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';
import 'package:school_library/school_library.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  final environment = ApiEnvironment.fromEnvironment();
  // Firebase and local storage are independent: init them together.
  await Future.wait([
    initFirebase(firebaseOptionsFor(environment)),
    () async {
      await configureDependencies(environment.name);
      // Hive must be open before AuthProvider restores the session from it.
      await getIt<StorageService>().init();
      await getIt<UserLocalStorage>().init();
    }(),
  ]);
  getIt<ApiClient>().source = 'web';
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
  runApp(PortalApp(authProvider: getIt<AuthProvider>()));
}

class PortalApp extends StatefulWidget {
  const PortalApp({required this.authProvider, super.key});

  final AuthProvider authProvider;

  @override
  State<PortalApp> createState() => _PortalAppState();
}

class _PortalAppState extends State<PortalApp> {
  late final _router = createRouter(widget.authProvider);
  late final _libraryProvider = getIt<LibraryProvider>();
  int? _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.authProvider.user?.id;
    _updateCrashlyticsUser();
    widget.authProvider.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final user = widget.authProvider.user;
    if (user?.id != _userId) {
      _libraryProvider.clearSession();
      _userId = user?.id;
    }
    _updateCrashlyticsUser();
  }

  void _updateCrashlyticsUser() {
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
    widget.authProvider.removeListener(_onAuthChanged);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider(create: (_) => getIt<InventoryProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<StockProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<ProcurementProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<AssetsProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<InsightsProvider>()),
        ChangeNotifierProvider.value(value: _libraryProvider),
        ChangeNotifierProvider(create: (_) => getIt<RoutesProvider>()),
      ],
      child: MaterialApp.router(
        title: 'iCue Portal',
        debugShowCheckedModeBanner: false,
        theme: IcueTheme.forEnvironment(
          isProd: ApiEnvironment.fromEnvironment().isProd,
        ),
        routerConfig: _router,
      ),
    );
  }
}
