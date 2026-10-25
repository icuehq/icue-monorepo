import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icueadmin/dialogs/logout_dialog.dart';
import 'package:icueadmin/features/dashboard/widgets/branch_selector_bar.dart';
import 'package:icueadmin/features/dashboard/widgets/sub_actions_sheet.dart';
import 'package:icueadmin/widgets/cache_image.dart';
import 'package:icueadmin/widgets/no_data_widget.dart';
import 'package:provider/provider.dart';

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
        child: actions.isEmpty
            ? (auth.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : const NoDataWidget(
                      size: 250,
                      msg: "You don't have access to any features. Please contact your administrator.",
                    ))
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
                    final hasSubActions =
                        item.subActionItems != null &&
                        item.subActionItems!.isNotEmpty;

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () {
                          if (hasSubActions) {
                            SubActionsSheet.show(
                              context,
                              action: item,
                              iconColor: Theme.of(context).primaryColorDark,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${item.displayName} selected'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 5, bottom: 5),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: iconPath != null
                                ? Image.asset(
                                    iconPath,
                                    errorBuilder: (_, _, _) =>
                                        CacheImage(url: item.icon, size: 56),
                                  )
                                : CacheImage(url: item.icon, size: 56),
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
                ),
              ),
      ),
    );
  }
}
