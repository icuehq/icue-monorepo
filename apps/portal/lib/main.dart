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
  await initFirebase(firebaseOptionsFor(environment));
  await configureDependencies(environment.name);
  getIt<ApiClient>().source = 'web';
  // Hive must be open before AuthProvider restores the session from it.
  await getIt<StorageService>().init();
  await getIt<UserLocalStorage>().init();
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
    widget.authProvider.addListener(_resetOnUserChange);
  }

  /// Library keeps per-session state, so drop it when the user changes.
  void _resetOnUserChange() {
    final id = widget.authProvider.user?.id;
    if (id != _userId) _libraryProvider.clearSession();
    _userId = id;
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_resetOnUserChange);
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
