import 'package:flutter/material.dart';
import 'package:icue_example/firebase_options.dart';
import 'package:icue_sdk/icue_sdk.dart';

import 'app_theme.dart';
import 'select_student_page.dart';
import 'session_manager.dart';
import 'student_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if a student session was previously saved locally.
  final savedSession = await SessionManager.getSession();

  // If a session already exists, initialize SDK automatically on startup.
  // Otherwise, SDK initialization is deferred until the user clicks Sign In.
  UserSession? initialSession = savedSession;
  if (savedSession != null) {
    try {
      await IcueSdk.init(
        savedSession.school.toSdkConfig(
          firebaseOptions: const IcueFirebaseOptions(
            android: DefaultFirebaseOptions.android,
            ios: DefaultFirebaseOptions.ios,
          ),
        ),
      );
      await IcueSdk.setIdentificationNo(savedSession.studentId);
    } catch (_) {
      // If initialization fails with saved credentials, clear corrupted state and prompt re-sign in
      initialSession = null;
      await SessionManager.clearSession();
    }
  }

  runApp(MyApp(savedSession: initialSession));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.savedSession});

  final UserSession? savedSession;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: IcueSdk.navigatorKey,
      navigatorObservers: [IcueNavigatorObserver()],
      title: 'iCue SDK Example',
      debugShowCheckedModeBanner: false,
      theme: prodTheme(),
      home: savedSession != null
          ? StudentDashboardPage(session: savedSession!)
          : const SelectStudentPage(),
    );
  }
}
