import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
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
  var _submitted = false;
  var _nextSample = 0;

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
            IcueButton(
              label: 'Keep editing',
              onPressed: () => Navigator.pop(context, false),
              variant: IcueButtonVariant.ghost,
            ),
            IcueButton(
              label: 'Discard',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _save() async {
    setState(() => _submitted = true);
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

  /// Fills the form with the next sample vendor (debug builds only).
  void _fillSample() {
    final sample = _sampleVendors[_nextSample++ % _sampleVendors.length];
    final categories = context.read<InventoryProvider>().topCategories;
    setState(() {
      _dirty = true;
      _name.text = sample.name;
      _contact.text = sample.contact;
      _phone.text = sample.phone;
      _email.text = sample.email;
      _website.text = sample.website;
      _address.text = sample.address;
      _tax.text = sample.tax;
      _remarks.text = sample.remarks;
      _categories
        ..clear()
        ..addAll(categories.take(2 + _nextSample % 2).map((c) => c.id));
    });
  }

  /// Two fields side by side when there is room, stacked on phones.
  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 520) {
        return Column(children: [first, const SizedBox(height: 14), second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryProvider = context.watch<InventoryProvider>();
    final categories = inventoryProvider.topCategories;
    if (widget.vendorId != null && !_editing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit vendor')),
        body: const IcueEmptyState(
          icon: Icons.store_mall_directory_outlined,
          title: 'Vendor not found',
          message: 'It may have been removed.',
        ),
      );
    }

    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Edit vendor' : 'New vendor'),
          actions: [
            if (kDebugMode && !_editing)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _fillSample,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: const Text('Fill sample'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ),
          ],
        ),
        body: Form(
          key: _form,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 900;
              final vendorCard = IcueFormSectionCard(
                title: 'Vendor',
                icon: Icons.business_rounded,
                children: [
                  IcueTextField(
                    controller: _name,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: requiredText,
                    label: 'Vendor name *',
                    hintText: 'e.g. Apex Office Supplies Pvt Ltd',
                  ),
                  _pair(
                    IcueTextField(
                      controller: _tax,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      label: 'GST / Tax ID',
                      hintText: 'e.g. 29AAAAA0000A1Z5',
                    ),
                    IcueTextField(
                      controller: _contact,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) => _maxLength(value, 120),
                      label: 'Contact person',
                    ),
                  ),
                ],
              );
              final contactCard = IcueFormSectionCard(
                title: 'Contact details',
                icon: Icons.contact_phone_outlined,
                children: [
                  _pair(
                    IcueTextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (value) => _optional(
                        value,
                        30,
                        pattern: _phonePattern,
                        message: 'Enter a valid phone number',
                      ),
                      label: 'Phone',
                      hintText: 'e.g. +91 98765 43210',
                      icon: Icons.phone_outlined,
                    ),
                    IcueTextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) => _optional(
                        value,
                        200,
                        pattern: _emailPattern,
                        message: 'Enter a valid email address',
                      ),
                      label: 'Email',
                      hintText: 'sales@apexsupplies.com',
                      icon: Icons.email_outlined,
                    ),
                  ),
                  IcueTextField(
                    controller: _website,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    validator: _validateWebsite,
                    label: 'Website',
                    hintText: 'www.apexsupplies.com',
                    icon: Icons.language_rounded,
                  ),
                  IcueTextField(
                    controller: _address,
                    maxLines: 2,
                    maxLength: 500,
                    label: 'Address',
                    icon: Icons.location_on_outlined,
                  ),
                ],
              );
              final categoriesCard = IcueFormSectionCard(
                title: 'Supplied categories',
                icon: Icons.category_outlined,
                children: [
                  if (inventoryProvider.isLoading && categories.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (categories.isEmpty)
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
                ],
              );
              final notesCard = IcueFormSectionCard(
                title: 'Notes',
                icon: Icons.notes_rounded,
                children: [
                  IcueTextField(
                    controller: _remarks,
                    maxLines: 3,
                    maxLength: 500,
                    label: 'Remarks (optional)',
                  ),
                ],
              );
              return SingleChildScrollView(
                padding: EdgeInsets.all(twoColumns ? 24 : 16),
                child: twoColumns
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(children: [vendorCard, contactCard]),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [categoriesCard, notesCard],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          vendorCard,
                          contactCard,
                          categoriesCard,
                          notesCard,
                        ],
                      ),
              );
            },
          ),
        ),
        bottomNavigationBar: Material(
          elevation: 8,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: IcueButton(
                      label: _busy
                          ? 'Saving…'
                          : _editing
                          ? 'Save changes'
                          : 'Create vendor',
                      isLoading: _busy,
                      onPressed: _busy ? null : _save,
                      leadingIcon: Icons.save_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _sampleVendors = [
  (
    name: 'Apex Office Supplies Pvt Ltd',
    contact: 'Rahul Mehta',
    phone: '+91 98765 43210',
    email: 'sales@apexsupplies.in',
    website: 'www.apexsupplies.in',
    address: '12, Industrial Estate, Peenya, Bengaluru 560058',
    tax: '29AAAAA0000A1Z5',
    remarks: 'Net 30 payment terms. Delivers within 3 days.',
  ),
  (
    name: 'Sri Lakshmi Stationers',
    contact: 'Lakshmi Narayan',
    phone: '+91 91234 56780',
    email: 'orders@srilakshmistationers.com',
    website: 'www.srilakshmistationers.com',
    address: '45, Main Bazaar, Tirupati, Andhra Pradesh 517501',
    tax: '37BBBBB1111B1Z2',
    remarks: 'Bulk discounts on notebooks and registers.',
  ),
  (
    name: 'TechNova Computers',
    contact: 'Anita Rao',
    phone: '+91 99887 76655',
    email: 'support@technova.co.in',
    website: 'technova.co.in',
    address: '8, Tech Park Road, Hitech City, Hyderabad 500081',
    tax: '36CCCCC2222C1Z8',
    remarks: 'Authorised reseller; 1-year onsite warranty.',
  ),
  (
    name: 'GreenLeaf Sports & Lab Equipments',
    contact: 'Imran Sheikh',
    phone: '+91 90000 11122',
    email: 'info@greenleafequip.com',
    website: 'www.greenleafequip.com',
    address: '22, Sports Complex Lane, Pune, Maharashtra 411001',
    tax: '27DDDDD3333D1Z4',
    remarks: 'Science lab kits and playground equipment.',
  ),
  (
    name: 'Bharat Furniture Works',
    contact: 'Suresh Kumar',
    phone: '+91 97000 22233',
    email: 'bharatfurniture@gmail.com',
    website: 'www.bharatfurniture.in',
    address: '5, Carpenter Street, Vijayawada, Andhra Pradesh 520001',
    tax: '37EEEEE4444E1Z6',
    remarks: 'Custom desks and benches; 2-week lead time.',
  ),
  (
    name: 'CleanPro Housekeeping Supplies',
    contact: 'Divya Reddy',
    phone: '+91 98450 33344',
    email: 'divya@cleanpro.in',
    website: 'www.cleanpro.in',
    address: '31, Mall Road, Chennai, Tamil Nadu 600001',
    tax: '33FFFFF5555F1Z1',
    remarks: 'Monthly consumables contract available.',
  ),
];
