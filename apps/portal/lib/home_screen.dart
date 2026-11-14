import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Where each role action (by its `RouteState`) opens in the portal.
const _routeByState = <String, String>{
  'layout.stationeryinventory': InventoryRoutes.inventory,
  'layout.library': LibraryRoutes.library,
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Provider notifies synchronously, which is illegal during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().getRoleActions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final actions = authProvider.roleActions;
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${authProvider.user?.name ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: authProvider.logout,
          ),
        ],
      ),
      body: authProvider.isLoading && actions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final action in actions)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.apps_rounded),
                      title: Text(action.displayName),
                      subtitle: Text(action.name),
                      onTap: () {
                        final route = _routeByState[action.routeState];
                        if (route != null) context.go(route);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
