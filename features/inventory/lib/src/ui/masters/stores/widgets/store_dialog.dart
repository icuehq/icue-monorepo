import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/person_search_field.dart';
import 'package:provider/provider.dart';

/// Adds a store or edits [store]: a dialog on wide screens, a full screen on phones.
class StoreDialog extends StatefulWidget {
  const StoreDialog({super.key, this.store});

  final InventoryStore? store;

  static Future<void> show(BuildContext context, {InventoryStore? store}) =>
      showFormPage(context, () => StoreDialog(store: store));

  @override
  State<StoreDialog> createState() => _StoreDialogState();
}

class _StoreDialogState extends State<StoreDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.store?.name);
  late final _description = TextEditingController(
    text: widget.store?.description,
  );
  late final _location = TextEditingController(text: widget.store?.location);
  late final Set<int> _storekeeperIds = {...?widget.store?.storekeeperIds};
  late int? _campus = widget.store?.campusId;
  int _nextSample = 0;
  bool _busy = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final access = context.read<InventoryProvider>().access;
    if (_campus == null && access.campusIds.length == 1) {
      _campus = access.campusIds.first;
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _description, _location]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Fills the form with the next sample whose name is not taken yet (debug builds, new stores only).
  void _fillSample() {
    final taken = {
      for (final store in context.read<InventoryProvider>().stores)
        store.name.trim().toLowerCase(),
    };
    for (var tried = 0; tried < _sampleStores.length; tried++) {
      final sample = _sampleStores[_nextSample++ % _sampleStores.length];
      if (taken.contains(sample.name.toLowerCase())) continue;
      setState(() {
        _name.text = sample.name;
        _location.text = sample.location;
        _description.text = sample.description;
      });
      return;
    }
    setState(() => _errorMessage = 'All sample stores already exist');
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final store = widget.store;
    final provider = context.read<InventoryProvider>();
    final saved = await submitAndClose<InventoryProvider>(
      context,
      () => provider.saveStore({
        if (store != null) 'id': store.id,
        'name': _name.text.trim(),
        'campusId': _campus,
        'description': blankToNull(_description),
        'location': blankToNull(_location),
        'storekeeperIds': _storekeeperIds.toList(),
      }),
    );
    if (mounted && !saved) {
      setState(() {
        _busy = false;
        _errorMessage = provider.errorMessage ?? 'Could not save store';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final access = context.read<InventoryProvider>().access;
    final editing = widget.store != null;
    final campuses = {...access.campusIds, ?_campus}.toList();

    return Form(
      key: _form,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.warehouse_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editing ? 'Edit Store' : 'New Store',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      editing
                          ? 'Update the details and storekeepers.'
                          : 'Set up a store and assign its storekeepers.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (kDebugMode && !editing)
                IcueButton(
                  label: 'Fill sample',
                  onPressed: _busy ? null : _fillSample,
                  variant: IcueButtonVariant.ghost,
                  leadingIcon: Icons.auto_fix_high_rounded,
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          IcueFormSectionCard(
            title: 'Store Details',
            icon: Icons.store_outlined,
            children: [
              IcueTextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                validator: requiredText,
                label: 'Store name *',
                hintText: 'e.g. Central Science Lab Store',
                icon: Icons.badge_outlined,
              ),
              if (campuses.length > 1)
                IcueDropdown<int>(
                  value: _campus,
                  items: [
                    for (final value in campuses)
                      DropdownMenuItem(
                        value: value,
                        child: Text('Campus $value'),
                      ),
                  ],
                  onChanged: editing
                      ? null
                      : (value) => setState(() => _campus = value),
                  validator: (value) => value == null ? 'Required' : null,
                  label: 'Campus *',
                  icon: Icons.school_outlined,
                ),
              IcueTextField(
                controller: _location,
                textInputAction: TextInputAction.next,
                label: 'Location',
                hintText: 'Building, floor or room number',
                icon: Icons.place_outlined,
              ),
              IcueTextField(
                controller: _description,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.next,
                label: 'Description',
                hintText: 'Optional notes or purpose of the store',
                icon: Icons.description_outlined,
              ),
            ],
          ),
          IcueFormSectionCard(
            title: 'Store Keepers',
            icon: Icons.people_outline,
            children: [
              if (_storekeeperIds.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final staffId in _storekeeperIds)
                      Chip(
                        avatar: const CircleAvatar(
                          child: Icon(Icons.person_outline, size: 16),
                        ),
                        label: Text(staffDisplayName(staffId)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () =>
                            setState(() => _storekeeperIds.remove(staffId)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              PersonSearchField(
                label: 'Add storekeeper',
                hint: 'Search staff by name or ID…',
                exclude: _storekeeperIds,
                clearOnSelect: true,
                onSelected: (staff) =>
                    setState(() => _storekeeperIds.add(staff.id)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IcueButton(
                label: 'Cancel',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                variant: IcueButtonVariant.outline,
              ),
              const SizedBox(width: 12),
              IcueButton(
                label: _busy
                    ? 'Saving…'
                    : (editing ? 'Save changes' : 'Create store'),
                onPressed: _busy ? null : _save,
                leadingIcon: Icons.check_rounded,
                isLoading: _busy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _sampleStores = [
  (
    name: 'Central Store',
    location: 'Main block, Ground floor',
    description: 'General stationery, cleaning and maintenance supplies.',
  ),
  (
    name: 'Science Lab Store',
    location: 'Science block, 1st floor',
    description: 'Lab equipment, chemicals and consumables.',
  ),
  (
    name: 'Sports Store',
    location: 'Near the playground',
    description: 'Sports kits, balls and training equipment.',
  ),
  (
    name: 'IT Store',
    location: 'Computer lab annexe',
    description: 'Computers, peripherals, cables and spare parts.',
  ),
];
