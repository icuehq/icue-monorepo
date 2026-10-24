import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/hive_service.dart';
import '../utils/app_update_checker.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await AppUpdateChecker().checkForUpdate();
      await HiveService.initialize();
      final userInfo = HiveService.userInfoBox.values.toList();
      if (userInfo.isEmpty) {
        await HiveService.clearAll();
        context.go('/login');
        return;
      } else {
        await Provider.of<AuthProvider>(
          context,
          listen: false,
        ).getRoleActions(context, isSplash: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 200),
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
