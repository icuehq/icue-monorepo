import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:school_library/school_library.dart';

/// Report catalogue (FRS 11.18).
class LibReportsPage extends StatelessWidget {
  const LibReportsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reports')),
    body: ListView(
      children: [
        for (final r in libraryReports)
          ListTile(
            title: Text(r.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.libraryReport, extra: r),
          ),
      ],
    ),
  );
}
