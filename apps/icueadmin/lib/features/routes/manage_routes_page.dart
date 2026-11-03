import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/option_card_tile.dart';

class ManageRoutesPage extends StatelessWidget {
  const ManageRoutesPage({super.key});

  static const _menuItems = [
    (
      title: 'Student / Staff Route Change',
      subtitle: 'Assign, shift or update student pickup and drop stops',
      iconAsset: 'assets/dashboard/student-route-change.png',
      route: AppRoutes.studentRouteChange,
    ),
    (
      title: 'Route Time Change',
      subtitle: 'Bulk or individually adjust scheduled start times',
      iconAsset: 'assets/dashboard/route-time-change.png',
      route: AppRoutes.routeTimeChange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Routes')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];

          return OptionCardTile(
            title: item.title,
            subtitle: item.subtitle,
            iconAsset: item.iconAsset,
            onTap: () => context.push(item.route),
          );
        },
      ),
    );
  }
}
