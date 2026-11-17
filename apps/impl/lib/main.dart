import 'dart:async';

import 'package:announcements/announcements.dart';
import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gatepass/gatepass.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:impl/bootstrap/app_bootstrap.dart';
import 'package:impl/di/injection.dart';
import 'package:impl/notifications/notification_tap.dart';
import 'package:impl/routing/app_router.dart';
import 'package:mess_meals/mess_meals.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:parent_transport/parent_transport.dart';
import 'package:provider/provider.dart';
import 'package:safehands/safehands.dart';
import 'package:school_connect/school_connect.dart';
import 'package:students/students.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  final environment = ApiEnvironment.fromEnvironment();
  runApp(
    AppBootstrap(
      environment: environment,
      builder: (connectivity) =>
          ParentApp(environment: environment, connectivity: connectivity),
    ),
  );
}

class ParentApp extends StatefulWidget {
  const ParentApp({
    required this.environment,
    required this.connectivity,
    super.key,
  });

  final ApiEnvironment environment;
  final IcueConnectivityService connectivity;

  @override
  State<ParentApp> createState() => _ParentAppState();
}

class _ParentAppState extends State<ParentApp> {
  final _auth = getIt<ParentAuthProvider>();
  final _students = getIt<ParentStudentsProvider>();
  final _locale = ValueNotifier<Locale>(const Locale('en'));
  late final GoRouter _router = createRouter(auth: _auth, locale: _locale);
  StreamSubscription<String>? _tokenSub;
  int? _trackedParentId;

  @override
  void initState() {
    super.initState();
    _trackedParentId = _auth.parentId;
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
    unawaited(NotificationService.instance.init(onTap: _onNotificationTap));
    _tokenSub = NotificationService.instance.onTokenRefresh.listen(
      _auth.registerPushToken,
    );
    if (_auth.isSignedIn) unawaited(_registerPushToken());
  }

  /// Switches to the student the push is about, then opens its screen.
  Future<void> _onNotificationTap(Map<String, dynamic> data) async {
    final tap = parseNotificationTap(data);
    if (tap == null || !_auth.isSignedIn) return;
    final student = _auth.students
        .where((s) => s.id == tap.studentId)
        .firstOrNull;
    if (student == null) return;
    _students.reset();
    await _auth.selectStudent(student);
    if (await _students.loadRoleActions(student.id)) _router.go(tap.path);
  }

  Future<void> _registerPushToken() async {
    final token = await NotificationService.instance.token;
    if (token != null) await _auth.registerPushToken(token);
  }

  /// Tags crash reports and analytics with the parent; clears them on logout.
  void _onAuthChanged() {
    final parentId = _auth.parentId;
    final signedIn = _auth.isSignedIn;
    final id = signedIn && parentId != null ? '$parentId' : null;
    CrashlyticsService.instance.setUser(id: id);
    AnalyticsService.instance.setUser(id: id);
    if (signedIn && parentId != _trackedParentId) {
      AnalyticsService.instance.logLogin('otp');
      unawaited(_registerPushToken());
    }
    if (!signedIn) _students.reset();
    _trackedParentId = signedIn ? parentId : null;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    unawaited(_tokenSub?.cancel());
    _router.dispose();
    _locale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ParentAuthProvider>.value(value: _auth),
        ChangeNotifierProvider<ParentStudentsProvider>.value(value: _students),
        ChangeNotifierProvider<ParentAnnouncementsProvider>.value(
          value: getIt<ParentAnnouncementsProvider>(),
        ),
        ChangeNotifierProvider<ParentTrackingProvider>.value(
          value: getIt<ParentTrackingProvider>(),
        ),
        ChangeNotifierProvider<RouteNotificationsProvider>.value(
          value: getIt<RouteNotificationsProvider>(),
        ),
        ChangeNotifierProvider<ParentVehiclesProvider>.value(
          value: getIt<ParentVehiclesProvider>(),
        ),
        ChangeNotifierProvider<TransportAttendanceProvider>.value(
          value: getIt<TransportAttendanceProvider>(),
        ),
        ChangeNotifierProvider<ComplaintsProvider>.value(
          value: getIt<ComplaintsProvider>(),
        ),
        ChangeNotifierProvider<EventsProvider>.value(
          value: getIt<EventsProvider>(),
        ),
        ChangeNotifierProvider<MealsProvider>.value(
          value: getIt<MealsProvider>(),
        ),
        ChangeNotifierProvider<SafeHandsProvider>.value(
          value: getIt<SafeHandsProvider>(),
        ),
        ChangeNotifierProvider<EscortProvider>.value(
          value: getIt<EscortProvider>(),
        ),
        ChangeNotifierProvider<ParentGatePassProvider>.value(
          value: getIt<ParentGatePassProvider>(),
        ),
        Provider<IcueConnectivityService>.value(value: widget.connectivity),
      ],
      child: ValueListenableBuilder<Locale>(
        valueListenable: _locale,
        builder: (context, locale, _) => MaterialApp.router(
          title: 'iCue Parent',
          debugShowCheckedModeBanner: false,
          theme: IcueTheme.forEnvironment(isProd: widget.environment.isProd),
          routerConfig: _router,
          locale: locale,
          localizationsDelegates: ParentLocalizations.localizationsDelegates,
          supportedLocales: ParentLocalizations.supportedLocales,
          builder: (context, child) => IcueConnectivityBanner(
            service: widget.connectivity,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
