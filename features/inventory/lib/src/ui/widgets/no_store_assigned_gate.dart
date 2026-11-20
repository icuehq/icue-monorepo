import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/providers/inventory_provider.dart';
import 'package:inventory/src/ui/widgets/store_manager_logout_button.dart';
import 'package:provider/provider.dart';

/// Shows [child] unless a store manager has no store assigned, then a "contact your branch admin" page.
class NoStoreAssignedGate extends StatefulWidget {
  const NoStoreAssignedGate({required this.child, super.key});

  final Widget child;

  @override
  State<NoStoreAssignedGate> createState() => _NoStoreAssignedGateState();
}

class _NoStoreAssignedGateState extends State<NoStoreAssignedGate> {
  bool _loaded = false;

  Future<void> _load() async {
    await context.read<InventoryProvider>().loadMasters();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void initState() {
    super.initState();
    if (context.read<AuthProvider>().isAssignedStoresOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      _loaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.read<AuthProvider>().isAssignedStoresOnly) {
      return widget.child;
    }
    final inventoryProvider = context.watch<InventoryProvider>();
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (inventoryProvider.errorMessage != null) {
      return Scaffold(
        body: IcueEmptyState.error(
          message: inventoryProvider.errorMessage,
          onAction: () {
            setState(() => _loaded = false);
            _load();
          },
        ),
      );
    }
    if (inventoryProvider.stores.isNotEmpty) return widget.child;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: const [StoreManagerLogoutButton()],
      ),
      body: const IcueEmptyState(
        icon: Icons.warehouse_outlined,
        title: 'No store assigned',
        message:
            'You have not been assigned to any store yet. '
            'Please contact your branch admin to get one assigned.',
        neutral: true,
      ),
    );
  }
}
