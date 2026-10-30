import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/dashboard/widgets/sub_actions_sheet.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class DashboardFeatureGrid extends StatelessWidget {
  const DashboardFeatureGrid({super.key});

  static const _palette = [
    Colors.blue,
    Colors.amber,
    Colors.deepPurple,
    Colors.teal,
    Colors.redAccent,
    Colors.indigo,
    Colors.green,
    Colors.orange,
  ];

  static IconData _resolveIcon(String iconName) {
    switch (iconName.toLowerCase().trim()) {
      case 'attendance':
      case 'fingerprint':
      case 'how_to_reg':
        return Icons.how_to_reg_rounded;
      case 'fleet':
      case 'bus':
      case 'transport':
      case 'vehicle':
      case 'directions_bus':
        return Icons.directions_bus_rounded;
      case 'announcement':
      case 'announcements':
      case 'campaign':
      case 'notice':
        return Icons.campaign_rounded;
      case 'standards':
      case 'standard':
      case 'class':
      case 'classes':
      case 'school':
        return Icons.class_rounded;
      case 'expense':
      case 'expenses':
      case 'receipt':
      case 'payment':
        return Icons.receipt_long_rounded;
      case 'report':
      case 'reports':
      case 'analytics':
        return Icons.analytics_rounded;
      case 'route':
      case 'routes':
      case 'map':
        return Icons.alt_route_rounded;
      case 'driver':
      case 'drivers':
      case 'person':
        return Icons.badge_rounded;
      case 'student':
      case 'students':
      case 'people':
        return Icons.people_alt_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'dashboard':
      case 'home':
        return Icons.dashboard_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final actions = auth.roleActions;

    if (auth.isLoading && actions.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading modules...',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (actions.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.dashboard_customize_rounded,
                  size: 44,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No modules assigned',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'No permission actions were returned for your role.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => auth.getRoleActions(),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.15,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final item = actions[index];
            final color = _palette[index % _palette.length];
            final title =
                item.displayName.isNotEmpty ? item.displayName : item.name;
            final icon = _resolveIcon(
              item.icon.isNotEmpty ? item.icon : item.name,
            );
            final hasSubActions =
                item.subActionItems != null && item.subActionItems!.isNotEmpty;

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (hasSubActions) {
                    SubActionsSheet.show(
                      context,
                      action: item,
                      iconColor: color,
                    );
                  } else {
                    final lowerTitle = title.toLowerCase();
                    final lowerRoute = item.routeState.toLowerCase();

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
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$title module selected'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              hasSubActions
                                  ? '${item.subActionItems!.length}'
                                  : 'Active',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasSubActions
                                ? '${item.subActionItems!.length} options'
                                : (item.routeState.isNotEmpty
                                    ? item.routeState
                                    : 'Available'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
