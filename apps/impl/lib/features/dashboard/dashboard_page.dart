import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:impl/features/dashboard/role_action_grid.dart';
import 'package:impl/routing/app_routes.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:parent_transport/parent_transport.dart';
import 'package:provider/provider.dart';
import 'package:students/students.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final students = context.read<ParentStudentsProvider>();
    await students.loadRoleActions();
    final granted = await NotificationService.instance.requestPermission();
    if (!granted && mounted) await _showNotificationsDisabled();
  }

  Future<void> _showNotificationsDisabled() {
    final l10n = ParentLocalizations.of(context);
    return IcueDialog.show<void>(
      context,
      title: l10n.notificationsDisabled,
      description: l10n.notificationDisabledContent,
      size: IcueDialogSize.small,
      secondaryAction: IcueDialogAction(
        label: l10n.cancel,
        variant: IcueButtonVariant.ghost,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      primaryAction: IcueDialogAction(
        label: l10n.openSettings,
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
          AppSettings.openAppSettings(type: AppSettingsType.notification);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<ParentStudentsProvider>();
    final items = students.roleActions.where((e) => e.isVisible).toList();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: SvgPicture.asset(IcueAssets.logoWhite, height: 28),
        actions: [
          IconButton(
            onPressed: () => context.go(AppRoutes.profile),
            icon: const Icon(Icons.person, color: Colors.white, size: 40),
          ),
        ],
      ),
      body: Column(
        children: [
          const LiveTrackingBanner(),
          Expanded(
            child: IcueSheetBody(
              loading: students.actionsLoading,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    const StudentHomeCard(),
                    RoleActionGrid(items: items),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
