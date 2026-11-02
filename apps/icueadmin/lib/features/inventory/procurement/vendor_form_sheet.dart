import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class VendorFormSheet extends StatefulWidget {
  const VendorFormSheet({super.key, this.vendor});

  final InventoryVendor? vendor;

  static Future<void> show(BuildContext context, {InventoryVendor? vendor}) =>
      showFormSheet(context, () => VendorFormSheet(vendor: vendor));

  @override
  State<VendorFormSheet> createState() => _VendorFormSheetState();
}

class _VendorFormSheetState extends State<VendorFormSheet> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.vendor?.code);
  late final _name = TextEditingController(text: widget.vendor?.name);
  late final _contact = TextEditingController(
    text: widget.vendor?.contactPerson,
  );
  late final _phone = TextEditingController(text: widget.vendor?.phone);
  late final _email = TextEditingController(text: widget.vendor?.email);
  late final _address = TextEditingController(text: widget.vendor?.address);
  late final _tax = TextEditingController(text: widget.vendor?.taxNumber);
  late final _website = TextEditingController(text: widget.vendor?.website);
  late final _remarks = TextEditingController(text: widget.vendor?.remarks);
  late final Set<String> _categories = {...?widget.vendor?.categoryIds};
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _contact,
      _phone,
      _email,
      _address,
      _tax,
      _website,
      _remarks,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final vendor = widget.vendor;
    String? blank(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    await procSubmit(
      context,
      (procurementProvider) => procurementProvider.saveVendor({
        if (vendor != null) 'id': vendor.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'contactPerson': blank(_contact),
        'phone': blank(_phone),
        'email': blank(_email),
        'address': blank(_address),
        'taxNumber': blank(_tax),
        'website': blank(_website),
        'categoryIds': _categories.toList(),
        'remarks': blank(_remarks),
      }),
      done: vendor == null ? 'Vendor created' : 'Vendor updated',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = context.read<InventoryProvider>().topCategories;

    return SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.vendor == null
                      ? Icons.add_business_rounded
                      : Icons.edit_note_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.vendor == null ? 'New Vendor' : 'Edit Vendor',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Basic Info
            TextFormField(
              controller: _code,
              enabled: widget.vendor == null,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Vendor code *',
                hintText: 'e.g. V-OFFICE-01',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
              validator: requiredText,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Vendor name *',
                hintText: 'e.g. Apex Office Supplies Pvt Ltd',
                prefixIcon: Icon(Icons.business_rounded),
              ),
              validator: requiredText,
            ),
            const SizedBox(height: 12),

            // Contact Info
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _contact,
                    decoration: const InputDecoration(
                      labelText: 'Contact person',
                      hintText: 'e.g. Rajesh Kumar',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      hintText: 'e.g. 9876543210',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'sales@apexsupplies.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _tax,
                    decoration: const InputDecoration(
                      labelText: 'GST / Tax ID',
                      hintText: 'e.g. 29AAAAA0000A1Z5',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'e.g. #14 Commercial Street, Bangalore',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _website,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Website',
                hintText: 'https://www.apexsupplies.com',
                prefixIcon: Icon(Icons.language_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _remarks,
              decoration: const InputDecoration(
                labelText: 'Notes / Remarks',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // Supply Categories
            Text(
              'Supplied Categories',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final category in categories)
                  FilterChip(
                    label: Text(category.name),
                    selected: _categories.contains(category.id),
                    onSelected: (isSelected) => setState(
                      () => isSelected
                          ? _categories.add(category.id)
                          : _categories.remove(category.id),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_busy ? 'Saving…' : 'Save Vendor'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
