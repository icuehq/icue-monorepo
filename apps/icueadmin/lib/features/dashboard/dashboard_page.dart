import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/dialogs/logout_dialog.dart';
import 'package:icueadmin/features/dashboard/widgets/branch_selector_bar.dart';
import 'package:icueadmin/widgets/option_card_tile.dart';
import 'package:provider/provider.dart';

const Map<String, String> _iconsMap = {
  'layout.trackvehicle': 'assets/dashboard/track-bus.png',
  'layout.fleetannouncement': 'assets/dashboard/announcements.png',
  'layout.routes': 'assets/dashboard/manage-routes.png',
  'layout.fleetdashboard': 'assets/dashboard/fleet.png',
  'layout.repairsandexpenses': 'assets/dashboard/manage-vehicles.png',
  'layout.fuelfilling': 'assets/dashboard/manage-expense.png',
  'layout.reports': 'assets/dashboard/reports.png',
  'layout.drivers': 'assets/dashboard/drivers.png',
  'layout.vehicles': 'assets/dashboard/vehicles.png',
  'layout.logbook': 'assets/dashboard/log-book.png',
  'layout.dropboarding': 'assets/dashboard/student-drop.png',
  'layout.gatepass': 'assets/dashboard/gate-pass.png',
  'layout.attendance': 'assets/dashboard/attendance.png',
  'layout.inventory': 'assets/dashboard/inventory.png',
  'layout.Library': 'assets/dashboard/library.png',
};

class DashboardPage extends StatefulWidget {
  const DashboardPage({this.environment, super.key});

  final ApiEnvironment? environment;

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
    if (!mounted) return;
    unawaited(context.read<AuthProvider>().getAdminAppSettings());
    await context.read<AuthProvider>().getRoleActions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final userInfo = auth.user;
    final actions = auth.roleActions;

    return Scaffold(
      backgroundColor: theme.colorScheme.secondary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.secondary,
        title: Image.asset(
          'assets/logo.png',
          height: 32,
          errorBuilder: (_, _, _) => const Icon(Icons.school, size: 28),
        ),
        actions: [
          IconButton(
            onPressed: () => showDialog<void>(
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
                    'Hi ${userInfo?.name ?? ""},\nWelcome back!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Image.asset(
                  'assets/vase.png',
                  width: 100,
                  height: 100,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 100, height: 100),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BranchSelectorBar(),
      body: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: actions.isEmpty && auth.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => context.read<AuthProvider>().getRoleActions(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 16,
                  ),
                  itemCount: actions.length,
                  itemBuilder: (context, index) {
                    final item = actions[index];
                    final iconPath = _iconsMap[item.routeState];

                    return OptionCardTile(
                      title: item.displayName,
                      iconAsset: iconPath,
                      networkIconUrl: item.icon,
                      onTap: () => context.push('/${item.routeState}'),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
