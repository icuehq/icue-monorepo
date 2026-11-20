import 'package:flutter/material.dart';
import 'package:icue_sdk/src/pages/initial_page.dart';
import 'package:icue_sdk/src/providers/notifications_provider.dart';
import 'package:icue_sdk/src/providers/user_provider.dart';
import 'package:icue_sdk/src/providers/vehicle_provider.dart';
import 'package:icue_sdk/src/services/injectable.dart';
import 'package:provider/provider.dart';

/// Composable module that wires up providers and renders the initial screen
/// for the Live Tracking flow.
class LiveTrackingModule extends StatelessWidget {
  const LiveTrackingModule({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: getIt<UserProvider>()),
        ChangeNotifierProvider.value(value: getIt<VehicleProvider>()),
        ChangeNotifierProvider.value(value: getIt<NotificationsProvider>()),
      ],
      child: const InitialPage(),
    );
  }
}
