import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';

/// Report catalogue (FRS 10.23).
class InventoryReportsPage extends StatelessWidget {
  const InventoryReportsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reports')),
    body: CenteredBody(
      maxWidth: 900,
      child: ListView(
        children: [
          for (final reportDef in inventoryReports)
            ListTile(
              title: Text(reportDef.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                InventoryRoutes.inventoryReport,
                extra: reportDef,
              ),
            ),
        ],
      ),
    ),
  );
}
