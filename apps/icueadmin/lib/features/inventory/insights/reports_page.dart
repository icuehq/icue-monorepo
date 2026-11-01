import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';

/// Report catalogue (FRS 10.23).
class InventoryReportsPage extends StatelessWidget {
  const InventoryReportsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reports')),
    body: ListView(
      children: [
        for (final r in inventoryReports)
          ListTile(
            title: Text(r.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.inventoryReport, extra: r),
          ),
      ],
    ),
  );
}
