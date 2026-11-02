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
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<InventoryProvider>().topCategories;
    TextFormField field(
      TextEditingController controller,
      String label, {
      bool required = false,
      TextInputType? type,
    }) => TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(labelText: required ? '$label *' : label),
      validator: required ? requiredText : null,
    );
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _code,
            enabled: widget.vendor == null,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Vendor code *'),
            validator: requiredText,
          ),
          field(_name, 'Vendor name', required: true),
          field(_contact, 'Contact person'),
          field(_phone, 'Phone', type: TextInputType.phone),
          field(_email, 'Email', type: TextInputType.emailAddress),
          field(_address, 'Address'),
          field(_tax, 'Tax registration no.'),
          field(_website, 'Website', type: TextInputType.url),
          field(_remarks, 'Notes'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
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
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
