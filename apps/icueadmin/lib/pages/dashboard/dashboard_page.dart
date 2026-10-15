import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../dialogs/logout_dialog.dart';
import '../../models/role_actions.dart';
import '../../providers/common_provider.dart';
import '../../services/hive_service.dart';
import '../../services/injectable.dart';
import '../../services/notification_service.dart';
import '../../widgets/cache_image.dart';
import '../../widgets/no_data_widget.dart';

const Map<String, String> _iconsMap = {
  'layout.trackvehicle': 'assets/dashboard/track-bus.png',
  'layout.fleetannouncement': 'assets/dashboard/announcements.png',
  'layout.routes': 'assets/dashboard/manage-routes.png',
  'layout.fleetdashboard': 'assets/dashboard/fleet.png',
  'layout.repairsandexpenses': 'assets/dashboard/manage-vehicles.png',
  'layout.fuelfilling': 'assets/dashboard/manage-expense.png',
  'layout.reports': 'assets/dashboard/reports.png',
  'layout.drivers': 'assets/dashboard/reports.png',
  'layout.vehicles': 'assets/dashboard/reports.png',
  'layout.logbook': 'assets/dashboard/log-book.png',
  'layout.dropboarding': 'assets/dashboard/student-drop.png',
};

const Map<String, IconData> _fallbackIconsMap = {
  'layout.exams': Icons.quiz_outlined,
  'layout.markscorrectionrequests': Icons.fact_check_outlined,
  'layout.leaves': Icons.event_note_outlined,
  'layout.homeassignments': Icons.assignment_outlined,
  'layout.attendance': Icons.how_to_reg_outlined,
};

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _initializePage());
  }

  Future<void> _initializePage() async {
    final notificationService = getIt<NotificationService>();
    await notificationService.initialize();

    if (!mounted) return;
    context.read<CommonProvider>().getAdminAppSettings();

    final permission = await notificationService.getPermissionStatus();
    if (permission != AuthorizationStatus.authorized) {
      _showNotificationPermissionDialog();
    }
  }

  void _showNotificationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Notifications'),
        content: const Text(
          'To stay up-to-date, please allow notifications in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              AppSettings.openAppSettings(type: AppSettingsType.notification);
              Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context, RoleActions item) {
    final iconPath = _iconsMap[item.routeState];
    if (iconPath != null) {
      return Image.asset(
        iconPath,
        errorBuilder: (_, _, _) => _buildFallbackLeading(context, item),
      );
    }
    return _buildFallbackLeading(context, item);
  }

  Widget _buildFallbackLeading(BuildContext context, RoleActions item) {
    if (item.icon.isNotEmpty) {
      return CacheImage(url: item.icon, size: 56);
    }
    final icon = _fallbackIconsMap[item.routeState] ?? Icons.widgets_outlined;
    final theme = Theme.of(context);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: theme.primaryColor, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userInfo = HiveService.userInfoBox.values.first;

    return Scaffold(
      backgroundColor: theme.colorScheme.secondary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.secondary,
        title: Image.asset('assets/logo.png', height: 32),
        actions: [
          // IconButton(
          //   onPressed: () {},
          //   icon: const Icon(
          //     Icons.notifications,
          //     size: 30,
          //     color: Colors.black,
          //   ),
          // ),
          IconButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const LogoutDialog(),
            ),
            icon: const Icon(Icons.logout, color: Colors.red),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Hi ${userInfo.name},\nWelcome back!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Image.asset('assets/vase.png', width: 100, height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _BranchSelectorBar(),
      body: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: ValueListenableBuilder(
          valueListenable: HiveService.getActionsByRoleBox.listenable(),
          builder: (context, box, _) {
            final actions = box.values.toList()
              ..sort((a, b) => a.tabOrder.compareTo(b.tabOrder));
            if (actions.isEmpty) {
              return const NoDataWidget(
                size: 250,
                msg:
                    "You don't have access to any features. Please contact your administrator.",
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final item = actions[index];
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () {
                      final route = item.routeState.startsWith('/')
                          ? item.routeState
                          : '/${item.routeState}';
                      context.go(route);
                    },
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 5),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _buildLeadingIcon(context, item),
                      ),
                    ),
                    title: Text(
                      item.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).primaryColorDark,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 24,
                      color: Theme.of(context).primaryColorDark,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BranchSelectorBar extends StatelessWidget {
  const _BranchSelectorBar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveService.zonalBranch.listenable(),
      builder: (context, box, _) {
        final zonalBranch = box.get('selected');
        if (zonalBranch == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  zonalBranch.schoolName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(100, 38),
                ),
                onPressed: () => context.push('/branches'),
                child: const Text('Change'),
              ),
            ],
          ),
        );
      },
    );
  }
}
