import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/di/injection.dart';
import 'package:icueadmin/routing/app_router.dart';
import 'package:icueadmin/theme/app_theme.dart';
import 'package:local_storage/local_storage.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Resolve environment from --dart-define=ENV or --dart-define=FLAVOR
  final env = ApiEnvironment.fromEnvironment();

  // 2. Initialize dependencies for this environment
  await configureDependencies(env.name);

  // 3. Initialize Hive storage service & restore user session box
  await getIt<StorageService>().init();
  await getIt<UserLocalStorage>().init();

  runApp(IcueAdminApp(environment: env));
}

class IcueAdminApp extends StatefulWidget {
  const IcueAdminApp({required this.environment, super.key});

  final ApiEnvironment environment;

  @override
  State<IcueAdminApp> createState() => _IcueAdminAppState();
}

class _IcueAdminAppState extends State<IcueAdminApp> {
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = getIt<AuthProvider>();
    _router = createRouter(
      authProvider: _authProvider,
      environment: widget.environment,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: _authProvider,
      child: MaterialApp.router(
        title: 'iCue Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forEnvironment(widget.environment),
        routerConfig: _router,
      ),
    );
  }
}
