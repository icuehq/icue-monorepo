import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/procurement/proc_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class VendorFormSheet extends StatefulWidget {
  const VendorFormSheet({super.key, this.vendor});

  final InvVendor? vendor;

  static Future<void> show(BuildContext context, {InvVendor? vendor}) =>
      showInvSheet(context, () => VendorFormSheet(vendor: vendor));

  @override
  State<VendorFormSheet> createState() => _VendorFormSheetState();
}

class _VendorFormSheetState extends State<VendorFormSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _code = TextEditingController(text: widget.vendor?.code);
  late final _name = TextEditingController(text: widget.vendor?.name);
  late final _contact = TextEditingController(
    text: widget.vendor?.contactPerson,
  );
  late final _phone = TextEditingController(text: widget.vendor?.phone);
  late final _email = TextEditingController(text: widget.vendor?.email);
  late final _address = TextEditingController(text: widget.vendor?.address);
  late final _tax = TextEditingController(text: widget.vendor?.taxNo);
  late final _website = TextEditingController(text: widget.vendor?.website);
  late final _notes = TextEditingController(text: widget.vendor?.notes);
  late final Set<String> _categories = {...?widget.vendor?.categoryIds};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _code,
      _name,
      _contact,
      _phone,
      _email,
      _address,
      _tax,
      _website,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final v = widget.vendor;
    String? blank(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    await procSubmit(
      context,
      (p) => p.act('inv-vendor-upsert', {
        if (v != null) 'id': v.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'contactPerson': blank(_contact),
        'phone': blank(_phone),
        'email': blank(_email),
        'address': blank(_address),
        'taxNo': blank(_tax),
        'website': blank(_website),
        'categoryIds': _categories.toList(),
        'notes': blank(_notes),
      }, requestId: _requestId),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.read<InventoryProvider>().topCategories;
    TextFormField field(
      TextEditingController c,
      String label, {
      bool required = false,
      TextInputType? type,
    }) => TextFormField(
      controller: c,
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
          field(_notes, 'Notes'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                for (final c in cats)
                  FilterChip(
                    label: Text(c.name),
                    selected: _categories.contains(c.id),
                    onSelected: (on) => setState(
                      () =>
                          on ? _categories.add(c.id) : _categories.remove(c.id),
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
