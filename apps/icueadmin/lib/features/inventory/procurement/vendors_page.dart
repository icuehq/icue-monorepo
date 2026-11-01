import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/vendor_form_sheet.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
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
      final inventoryProvider = context.read<InventoryProvider>();
      if (inventoryProvider.categories.isEmpty) {
        await inventoryProvider.loadMasters();
      }
      if (mounted) await context.read<ProcurementProvider>().loadVendors();
    });
  }

  Future<void> _toggle(InventoryVendor vendor) async {
    final procurementProvider = context.read<ProcurementProvider>();
    final result = await procurementProvider.act('inventory-vendor-setStatus', {
      'id': vendor.id,
      'status': vendor.active ? 'inactive' : 'active',
    });
    if (!mounted) return;
    if (result == null) {
      return showMessage(context, procurementProvider.errorMessage ?? 'Failed');
    }
    await procurementProvider.loadVendors();
  }

  @override
  Widget build(BuildContext context) {
    final procurementProvider = context.watch<ProcurementProvider>();
    final canEdit = context.read<InventoryProvider>().access.can(
      'inventory.vendors.manage',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () async {
                await VendorFormSheet.show(context);
                if (mounted) await procurementProvider.loadVendors();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Vendor'),
            )
          : null,
      body: procurementProvider.vendors.isEmpty
          ? Center(
              child: procurementProvider.isLoading
                  ? const CircularProgressIndicator()
                  : Text(procurementProvider.errorMessage ?? 'No vendors yet'),
            )
          : ListView(
              children: [
                for (final vendor in procurementProvider.vendors)
                  ListTile(
                    title: Text(vendor.name),
                    subtitle: Text(
                      [
                        vendor.code,
                        ?vendor.contactPerson,
                        ?vendor.phone,
                      ].join(' · '),
                    ),
                    leading: vendor.active ? null : const InactiveBadge(),
                    trailing: canEdit
                        ? PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await VendorFormSheet.show(
                                  context,
                                  vendor: vendor,
                                );
                                if (mounted) {
                                  await procurementProvider.loadVendors();
                                }
                              } else {
                                await _toggle(vendor);
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
                                  vendor.active ? 'Deactivate' : 'Activate',
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
