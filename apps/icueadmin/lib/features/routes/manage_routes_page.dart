import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';

class ManageRoutesPage extends StatelessWidget {
  const ManageRoutesPage({super.key});

  static const _menuItems = [
    (
      title: 'Student / Staff Route Change',
      subtitle: 'Assign, shift or update student pickup and drop stops',
      icon: Icons.alt_route_rounded,
      route: AppRoutes.studentRouteChange,
    ),
    (
      title: 'Route Time Change',
      subtitle: 'Bulk or individually adjust scheduled start times',
      icon: Icons.update_rounded,
      route: AppRoutes.routeTimeChange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Routes')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _menuItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _menuItems[index];

          return Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              onTap: () => context.push(item.route),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                child: Icon(item.icon, color: theme.primaryColor, size: 22),
              ),
              title: Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                item.subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }
}
