import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/person_search_field.dart';
import 'package:provider/provider.dart';

class StoreFormPage extends StatefulWidget {
  const StoreFormPage({super.key, this.store});

  final InventoryStore? store;

  @override
  State<StoreFormPage> createState() => _StoreFormPageState();
}

class _StoreFormPageState extends State<StoreFormPage> {
  final _form = GlobalKey<FormState>();
  late final InventoryStore? _existingStore = widget.store;
  late final _name = TextEditingController(text: _existingStore?.name);
  late final _description = TextEditingController(
    text: _existingStore?.description,
  );
  late final _location = TextEditingController(text: _existingStore?.location);
  late final Set<int> _storekeeperIds = {...?_existingStore?.storekeeperIds};
  int? _campus;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final access = context.read<InventoryProvider>().access;
    _campus =
        _existingStore?.campusId ??
        (access.campusIds.length == 1 ? access.campusIds.first : null);
  }

  @override
  void dispose() {
    for (final controller in [_name, _description, _location]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final store = _existingStore;
    final access = context.read<InventoryProvider>().access;
    final campuses = {...access.campusIds, ?_campus}.toList();
    final campusId = _campus ?? (campuses.length == 1 ? campuses.first : null);
    if (campusId == null) {
      showMessage(context, 'Campus is required');
      setState(() => _busy = false);
      return;
    }
    String? blank(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    await submitAndClose<InventoryProvider>(
      context,
      () => context.read<InventoryProvider>().saveStore({
        if (store != null) 'id': store.id,
        'name': _name.text.trim(),
        'campusId': campusId,
        'description': blank(_description),
        'location': blank(_location),
        'storekeeperIds': _storekeeperIds.toList(),
      }),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final access = context.read<InventoryProvider>().access;
    final editing = _existingStore != null;
    final campuses = {...access.campusIds, ?_campus}.toList();
    if (_campus == null && campuses.length == 1) {
      _campus = campuses.first;
    }
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit store' : 'Add store')),
      body: CenteredBody(
        maxWidth: Breakpoints.formMaxWidth,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              FormSectionCard(
                title: 'Store Details',
                icon: Icons.store_outlined,
                children: [
                  AppTextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    validator: requiredText,
                    label: 'Store name *',
                    hintText: 'e.g. Central Science Lab Store',
                    icon: Icons.badge_outlined,
                  ),
                  if (campuses.length > 1)
                    AppDropdown<int>(
                      value: _campus,
                      items: [
                        for (final value in campuses)
                          DropdownMenuItem(
                            value: value,
                            child: Text('Campus $value'),
                          ),
                      ],
                      onChanged: editing ? null : (value) => _campus = value,
                      validator: (value) => value == null ? 'Required' : null,
                      label: 'Campus *',
                      icon: Icons.school_outlined,
                    ),
                  AppTextField(
                    controller: _location,
                    textInputAction: TextInputAction.next,
                    label: 'Location',
                    hintText: 'Building, floor or room number',
                    icon: Icons.place_outlined,
                  ),
                  AppTextField(
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
              FormSectionCard(
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _busy
                        ? 'Saving…'
                        : (editing ? 'Update store' : 'Save store'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
