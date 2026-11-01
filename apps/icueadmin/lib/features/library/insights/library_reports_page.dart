import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:school_library/school_library.dart';

/// Report catalogue (FRS 11.18).
class LibraryReportsPage extends StatelessWidget {
  const LibraryReportsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reports')),
    body: ListView(
      children: [
        for (final reportDef in libraryReports)
          ListTile(
            title: Text(reportDef.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push(AppRoutes.libraryReport, extra: reportDef),
          ),
      ],
    ),
  );
}
