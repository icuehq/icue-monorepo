import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/vendor_form_sheet.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Vendors (FRS 10.14). Purchase history, quotations, POs and invoices arrive with Inv-4/5.
class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final inv = context.read<InventoryProvider>();
      if (inv.categories.isEmpty) await inv.loadMasters();
      if (mounted) await context.read<ProcurementProvider>().loadVendors();
    });
  }

  Future<void> _toggle(InvVendor v) async {
    final p = context.read<ProcurementProvider>();
    final res = await p.act('inv-vendor-setStatus', {
      'id': v.id,
      'status': v.active ? 'inactive' : 'active',
    });
    if (!mounted) return;
    if (res == null) return invSnack(context, p.errorMessage ?? 'Failed');
    await p.loadVendors();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProcurementProvider>();
    final canEdit = context.read<InventoryProvider>().access.can(
      'inv.vendors.manage',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () async {
                await VendorFormSheet.show(context);
                if (mounted) await p.loadVendors();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Vendor'),
            )
          : null,
      body: p.vendors.isEmpty
          ? Center(
              child: p.isLoading
                  ? const CircularProgressIndicator()
                  : Text(p.errorMessage ?? 'No vendors yet'),
            )
          : ListView(
              children: [
                for (final v in p.vendors)
                  ListTile(
                    title: Text(v.name),
                    subtitle: Text(
                      [v.code, ?v.contactPerson, ?v.phone].join(' · '),
                    ),
                    leading: v.active ? null : const InactiveBadge(),
                    trailing: canEdit
                        ? PopupMenuButton<String>(
                            onSelected: (a) async {
                              if (a == 'edit') {
                                await VendorFormSheet.show(context, vendor: v);
                                if (mounted) await p.loadVendors();
                              } else {
                                await _toggle(v);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  v.active ? 'Deactivate' : 'Activate',
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}
