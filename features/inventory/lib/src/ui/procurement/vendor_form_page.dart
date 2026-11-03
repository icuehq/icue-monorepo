import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _phonePattern = RegExp(r'^[+()\d\s-]{7,30}$');

String? _maxLength(String? value, int max) =>
    (value?.trim().length ?? 0) > max ? 'At most $max characters' : null;

/// Creates a vendor, or edits the one named by [vendorId] (FRS 10.14).
class VendorFormPage extends StatefulWidget {
  const VendorFormPage({this.vendorId, super.key});

  final String? vendorId;

  @override
  State<VendorFormPage> createState() => _VendorFormPageState();
}

class _VendorFormPageState extends State<VendorFormPage> {
  final _form = GlobalKey<FormState>();
  late final InventoryVendor? _vendor = context
      .read<ProcurementProvider>()
      .vendors
      .where((vendor) => vendor.id == widget.vendorId)
      .firstOrNull;
  late final _name = TextEditingController(text: _vendor?.name);
  late final _contact = TextEditingController(text: _vendor?.contactPerson);
  late final _phone = TextEditingController(text: _vendor?.phone);
  late final _email = TextEditingController(text: _vendor?.email);
  late final _address = TextEditingController(text: _vendor?.address);
  late final _tax = TextEditingController(text: _vendor?.taxNumber);
  late final _website = TextEditingController(text: _vendor?.website);
  late final _remarks = TextEditingController(text: _vendor?.remarks);
  late final Set<String> _categories = {...?_vendor?.categoryIds};
  var _dirty = false;
  var _busy = false;

  bool get _editing => _vendor != null;

  @override
  void initState() {
    super.initState();
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => inventoryProvider.loadMasters(),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in [
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

  String? _optional(
    String? value,
    int max, {
    RegExp? pattern,
    String message = 'Invalid value',
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return _maxLength(text, max) ??
        (pattern != null && !pattern.hasMatch(text) ? message : null);
  }

  String? _validateWebsite(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final length = _maxLength(text, 200);
    if (length != null) return length;
    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    return uri == null || !uri.host.contains('.')
        ? 'Enter a valid website'
        : null;
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your changes to this vendor are not saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: Size.zero),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final procurementProvider = context.read<ProcurementProvider>();
    final navigator = Navigator.of(context);
    var website = blankToNull(_website);
    if (website != null && !website.contains('://')) {
      website = 'https://$website';
    }
    setState(() => _busy = true);
    final vendor = _vendor;
    final saved = await procurementProvider.saveVendor({
      'id': ?vendor?.id,
      'name': _name.text.trim(),
      'contactPerson': blankToNull(_contact),
      'phone': blankToNull(_phone),
      'email': blankToNull(_email),
      'address': blankToNull(_address),
      'taxNumber': blankToNull(_tax),
      'website': website,
      'categoryIds': _categories.toList(),
      'remarks': blankToNull(_remarks),
    });
    if (!mounted) return;
    if (saved == null) {
      setState(() => _busy = false);
      return showMessage(
        context,
        procurementProvider.errorMessage ?? 'Could not save',
      );
    }
    await procurementProvider.loadVendors();
    if (!mounted) return;
    showMessage(context, _editing ? 'Vendor updated' : 'Vendor created');
    setState(() => _dirty = false);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = context.watch<InventoryProvider>().topCategories;
    if (widget.vendorId != null && !_editing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit vendor')),
        body: const Center(child: Text('Vendor not found')),
      );
    }

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit vendor' : 'New vendor')),
        body: Form(
          key: _form,
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Vendor name *',
                  hintText: 'e.g. Apex Office Supplies Pvt Ltd',
                  prefixIcon: Icon(Icons.business_rounded),
                ),
                validator: requiredText,
              ),
              section('Contact'),
              TextFormField(
                controller: _contact,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Contact person',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => _maxLength(value, 120),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'e.g. +91 98765 43210',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) => _optional(
                  value,
                  30,
                  pattern: _phonePattern,
                  message: 'Enter a valid phone number',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'sales@apexsupplies.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) => _optional(
                  value,
                  200,
                  pattern: _emailPattern,
                  message: 'Enter a valid email address',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _website,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Website',
                  hintText: 'www.apexsupplies.com',
                  prefixIcon: Icon(Icons.language_rounded),
                ),
                validator: _validateWebsite,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              section('Tax'),
              TextFormField(
                controller: _tax,
                maxLength: 40,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'GST / Tax ID',
                  hintText: 'e.g. 29AAAAA0000A1Z5',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
              section('Supplied categories'),
              if (categories.isEmpty)
                Text(
                  'No categories yet. Add item categories first to map vendors to them.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final category in categories)
                      FilterChip(
                        label: Text(category.name),
                        selected: _categories.contains(category.id),
                        onSelected: (selected) => setState(() {
                          _dirty = true;
                          selected
                              ? _categories.add(category.id)
                              : _categories.remove(category.id);
                        }),
                      ),
                  ],
                ),
              section('Notes'),
              TextFormField(
                controller: _remarks,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Material(
          elevation: 8,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(_busy ? 'Saving…' : 'Save vendor'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
