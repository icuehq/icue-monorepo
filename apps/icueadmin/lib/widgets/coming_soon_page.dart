import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';

/// Shown for routes the app does not know, such as a module the backend lists
/// before this app supports it.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coming Soon')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_rounded, size: 72),
              const SizedBox(height: 16),
              const Text(
                'This feature is coming soon.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Go To Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
