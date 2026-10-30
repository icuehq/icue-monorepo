import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';

/// Modal bottom sheet displaying sub-action items for a selected module.
class SubActionsSheet extends StatelessWidget {
  const SubActionsSheet({
    required this.action,
    required this.iconColor,
    super.key,
  });

  final RoleActions action;
  final Color iconColor;

  static Future<void> show(
    BuildContext context, {
    required RoleActions action,
    required Color iconColor,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SubActionsSheet(
        action: action,
        iconColor: iconColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subItems = action.subActionItems ?? const <RoleActions>[];
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: iconColor.withValues(alpha: 0.15),
                  child: Icon(Icons.apps_rounded, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.displayName.isNotEmpty
                            ? action.displayName
                            : action.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${subItems.length} available actions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: subItems.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final sub = subItems[index];
                  final title =
                      sub.displayName.isNotEmpty ? sub.displayName : sub.name;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: iconColor.withValues(alpha: 0.1),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      final lowerTitle = title.toLowerCase();
                      final lowerRoute = sub.routeState.toLowerCase();

                      if (lowerTitle.contains('add driver') ||
                          lowerRoute.contains('add-driver')) {
                        context.push(AppRoutes.addDriver);
                      } else if (lowerTitle.contains('driver') ||
                          lowerRoute.contains('driver')) {
                        context.push(AppRoutes.drivers);
                      } else if (lowerTitle.contains('add vehicle') ||
                          lowerRoute.contains('add-vehicle')) {
                        context.push(AppRoutes.addVehicle);
                      } else if (lowerTitle.contains('vehicle') ||
                          lowerTitle.contains('fleet') ||
                          lowerRoute.contains('vehicle') ||
                          lowerRoute.contains('fleet')) {
                        context.push(AppRoutes.vehicles);
                      } else if (lowerTitle.contains('student') &&
                              lowerTitle.contains('route') ||
                          lowerRoute.contains('student-route')) {
                        context.push(AppRoutes.studentRouteChange);
                      } else if (lowerTitle.contains('time') &&
                              lowerTitle.contains('route') ||
                          lowerRoute.contains('route-time')) {
                        context.push(AppRoutes.routeTimeChange);
                      } else if (lowerTitle.contains('route') ||
                          lowerRoute.contains('route')) {
                        context.push(AppRoutes.manageRoutes);
                      } else if (lowerTitle.contains('post') &&
                              lowerTitle.contains('announcement') ||
                          lowerRoute.contains('post') ||
                          lowerRoute.contains('createfleetannouncement')) {
                        context.push(AppRoutes.postAnnouncement);
                      } else if (lowerTitle.contains('announcement') ||
                          lowerRoute.contains('announcement')) {
                        context.push(AppRoutes.announcements);
                      } else if (lowerTitle.contains('repairs') ||
                          lowerTitle.contains('expense') ||
                          lowerRoute.contains('repairs') ||
                          lowerRoute.contains('expense')) {
                        context.push(AppRoutes.repairsExpense);
                      } else if (lowerTitle.contains('fuel') ||
                          lowerRoute.contains('fuel')) {
                        context.push(AppRoutes.manageExpense);
                      } else if (lowerTitle.contains('alcohol') ||
                          lowerRoute.contains('alcohol')) {
                        context.push(AppRoutes.alcoholTestForm);
                      } else if (lowerTitle.contains('clean') ||
                          lowerRoute.contains('clean')) {
                        context.push(AppRoutes.cleaningLog);
                      } else if (lowerTitle.contains('complaint') ||
                          lowerRoute.contains('complaint')) {
                        context.push(AppRoutes.complaintsDashboard);
                      } else if (lowerTitle.contains('arrival') ||
                          lowerRoute.contains('arrival')) {
                        context.push(AppRoutes.arrivalTimeReport);
                      } else if (lowerTitle.contains('clean') &&
                          (lowerTitle.contains('report') ||
                              lowerRoute.contains('report'))) {
                        context.push(AppRoutes.cleaningReport);
                      } else if (lowerTitle.contains('alcohol') &&
                          (lowerTitle.contains('report') ||
                              lowerRoute.contains('report'))) {
                        context.push(AppRoutes.alcoholTestReport);
                      } else if (lowerTitle.contains('fuel') &&
                          (lowerTitle.contains('report') ||
                              lowerRoute.contains('report'))) {
                        context.push(AppRoutes.fuelReport);
                      } else if (lowerTitle.contains('mileage') ||
                          lowerRoute.contains('mileage')) {
                        context.push(AppRoutes.mileageReport);
                      } else if (lowerTitle.contains('speed') ||
                          lowerRoute.contains('overspeed') ||
                          lowerRoute.contains('over-speed')) {
                        context.push(AppRoutes.overSpeedReport);
                      } else if (lowerTitle.contains('log') ||
                          lowerRoute.contains('logbook')) {
                        context.push(AppRoutes.logBook);
                      } else if (lowerTitle.contains('report') ||
                          lowerRoute.contains('report')) {
                        context.push(AppRoutes.reports);
                      } else if (lowerTitle.contains('generate') &&
                          (lowerTitle.contains('gate') ||
                              lowerRoute.contains('gate'))) {
                        context.push(AppRoutes.generateGatePass);
                      } else if ((lowerTitle.contains('approve') &&
                              (lowerTitle.contains('gate') ||
                                  lowerRoute.contains('gate'))) ||
                          lowerRoute.contains('approvegatepass')) {
                        context.push(AppRoutes.pendingGatePass);
                      } else if (lowerTitle.contains('gate') ||
                          lowerRoute.contains('gatepass')) {
                        context.push(AppRoutes.gatePass);
                      } else if (lowerTitle.contains('fleet') &&
                          lowerTitle.contains('status')) {
                        context.push(AppRoutes.fleetStatus);
                      } else if (lowerTitle.contains('track') ||
                          lowerRoute.contains('track')) {
                        context.push(AppRoutes.trackBus);
                      } else if (lowerTitle.contains('drop-off') ||
                          lowerTitle.contains('drop vehicles') ||
                          lowerRoute.contains('dropvehicles')) {
                        context.push(AppRoutes.dropVehicles);
                      } else if (lowerTitle.contains('boarding') ||
                          lowerRoute.contains('boarding')) {
                        context.push(AppRoutes.boarding);
                      } else if (lowerTitle.contains('drop') ||
                          lowerRoute.contains('drop')) {
                        context.push(AppRoutes.dropBoarding);
                      } else if (lowerTitle.contains('attend') ||
                          lowerRoute.contains('attend')) {
                        context.push(AppRoutes.attendance);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$title selected'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
