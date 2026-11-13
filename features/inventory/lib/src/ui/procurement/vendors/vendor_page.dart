import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/vendors/vendor_actions.dart';
import 'package:provider/provider.dart';

/// Everything known about one vendor, with edit and (de)activate.
class VendorPage extends StatefulWidget {
  const VendorPage({required this.vendorId, super.key});

  final String vendorId;

  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage> {
  /// False until the first fetch ends, so "not found" never flashes.
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) await context.read<ProcurementProvider>().loadVendors();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _edit(InventoryVendor vendor) async {
    await context.push(
      '${InventoryRoutes.inventoryVendorForm}?id=${vendor.id}',
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final procurementProvider = context.watch<ProcurementProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.vendors.manage');
    final vendor = procurementProvider.vendors
        .where((candidate) => candidate.id == widget.vendorId)
        .firstOrNull;

    if (vendor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vendor')),
        body: !_loaded
            ? const IcueLoadingState(label: 'Loading vendor…')
            : procurementProvider.errorMessage != null
            ? IcueEmptyState.error(
                title: 'Could not load vendor',
                message: procurementProvider.errorMessage!,
                onAction: _load,
              )
            : const IcueEmptyState(
                icon: Icons.store_mall_directory_outlined,
                title: 'Vendor not found',
                message: 'It may have been removed.',
              ),
      );
    }

    final categoryNames = [
      for (final categoryId in vendor.categoryIds)
        inventoryProvider.categories
                .where((category) => category.id == categoryId)
                .firstOrNull
                ?.name ??
            categoryId,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(vendor.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 900;
            final header = _Header(
              vendor: vendor,
              canEdit: canEdit,
              onEdit: () => _edit(vendor),
            );
            final contact = _ContactCard(vendor: vendor);
            final business = _BusinessCard(vendor: vendor);
            final categories = _CategoriesCard(names: categoryNames);
            final remarks = IcueFormSectionCard(
              title: 'Remarks',
              icon: Icons.notes_rounded,
              children: [SelectableText(vendor.remarks ?? '')],
            );
            final hasBusiness =
                vendor.address != null || vendor.taxNumber != null;
            final hasRemarks = (vendor.remarks ?? '').isNotEmpty;
            final left = [contact, if (hasRemarks) remarks];
            final right = [if (hasBusiness) business, categories];
            return ListView(
              padding: EdgeInsets.all(twoColumns ? 24 : 16),
              children: [
                header,
                if (twoColumns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: left)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(children: right)),
                    ],
                  )
                else ...[
                  contact,
                  ...right,
                  if (hasRemarks) remarks,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.vendor,
    required this.canEdit,
    required this.onEdit,
  });

  final InventoryVendor vendor;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IcueFormSectionCard(
      title: vendor.name,
      icon: Icons.store_mall_directory_outlined,
      trailing: IcueStatusPill(
        label: vendor.active ? 'Active' : 'Inactive',
        color: vendor.active ? Colors.green : Colors.grey,
        compact: true,
      ),
      children: [
        if (!vendor.active)
          Text(
            'Inactive vendors cannot be chosen on new quotations or orders.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        if (canEdit)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IcueButton(
                label: 'Edit',
                onPressed: onEdit,
                variant: IcueButtonVariant.outline,
                leadingIcon: Icons.edit_outlined,
              ),
              IcueButton(
                label: vendor.active ? 'Deactivate' : 'Activate',
                onPressed: () => toggleVendorActive(context, vendor),
                variant: IcueButtonVariant.outline,
                leadingIcon: vendor.active
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
              ),
            ],
          ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.vendor});

  final InventoryVendor vendor;

  @override
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: 'Contact',
    icon: Icons.contact_phone_outlined,
    children: [
      _Field(
        Icons.person_outline_rounded,
        'Contact person',
        vendor.contactPerson,
      ),
      _Field(Icons.phone_outlined, 'Phone', vendor.phone, copyable: true),
      _Field(Icons.email_outlined, 'Email', vendor.email, copyable: true),
      _Field(Icons.language_rounded, 'Website', vendor.website, copyable: true),
      if ([
        vendor.contactPerson,
        vendor.phone,
        vendor.email,
        vendor.website,
      ].every((value) => (value ?? '').isEmpty))
        const Text('No contact details added'),
    ],
  );
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.vendor});

  final InventoryVendor vendor;

  @override
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: 'Business',
    icon: Icons.receipt_long_outlined,
    children: [
      _Field(
        Icons.receipt_long_outlined,
        'GST / Tax ID',
        vendor.taxNumber,
        copyable: true,
      ),
      _Field(Icons.location_on_outlined, 'Address', vendor.address),
    ],
  );
}

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: 'Supplied categories',
    icon: Icons.category_outlined,
    children: [
      if (names.isEmpty)
        const Text('No categories mapped')
      else
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [for (final name in names) Chip(label: Text(name))],
        ),
    ],
  );
}

/// A labelled value with an optional copy button; renders nothing when empty.
class _Field extends StatelessWidget {
  const _Field(this.icon, this.label, this.value, {this.copyable = false});

  final IconData icon;
  final String label;
  final String? value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(text, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) showMessage(context, '$label copied');
            },
          ),
      ],
    );
  }
}
