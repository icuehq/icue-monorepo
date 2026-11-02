import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/form_section_card.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

// TODO: Connect to Node ERP staff lookup endpoint when available.
class StaffOption {
  const StaffOption({
    required this.id,
    required this.name,
    required this.department,
  });

  final int id;
  final String name;
  final String department;
}

// TODO: Replace with live API search once the Node ERP endpoint is ready.
const List<StaffOption> _sampleStaffList = [
  StaffOption(id: 101, name: 'John Doe', department: 'Operations'),
  StaffOption(id: 102, name: 'Sarah Smith', department: 'Science'),
  StaffOption(id: 103, name: 'Michael Brown', department: 'Sports'),
  StaffOption(id: 104, name: 'Emily Davis', department: 'Administration'),
  StaffOption(id: 105, name: 'David Wilson', department: 'Logistics'),
];

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
  TextEditingController? _staffSearchController;
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

  static String _generateStoreCode(String text) {
    final cleaned = text
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.isEmpty) {
      return 'STORE_${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    }
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  String _staffDisplayName(int staffId) {
    for (final staff in _sampleStaffList) {
      if (staff.id == staffId) {
        return '${staff.name} (#$staffId)';
      }
    }
    return 'Staff #$staffId';
  }

  Iterable<StaffOption> _searchStaff(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];
    // TODO: Connect to Node ERP staff lookup endpoint when available.
    final matches = _sampleStaffList.where((staff) {
      return !_storekeeperIds.contains(staff.id) &&
          (staff.name.toLowerCase().contains(trimmed) ||
              staff.department.toLowerCase().contains(trimmed) ||
              staff.id.toString().contains(trimmed));
    }).toList();
    final numericId = int.tryParse(trimmed);
    if (numericId != null &&
        !_storekeeperIds.contains(numericId) &&
        !matches.any((staff) => staff.id == numericId)) {
      matches.add(
        StaffOption(
          id: numericId,
          name: 'Staff #$numericId',
          department: 'ERP Staff',
        ),
      );
    }
    return matches;
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
        if (store != null)
          'id': store.id
        else
          'code': _generateStoreCode(_name.text),
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
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            FormSectionCard(
              title: 'Store Details',
              icon: Icons.store_outlined,
              children: [
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Store name *',
                    hintText: 'e.g. Central Science Lab Store',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                  validator: requiredText,
                ),
                if (campuses.length > 1)
                  DropdownButtonFormField<int>(
                    initialValue: _campus,
                    decoration: const InputDecoration(
                      labelText: 'Campus *',
                      prefixIcon: Icon(Icons.school_outlined, size: 20),
                    ),
                    items: [
                      for (final value in campuses)
                        DropdownMenuItem(
                          value: value,
                          child: Text('Campus $value'),
                        ),
                    ],
                    onChanged: editing ? null : (value) => _campus = value,
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                TextFormField(
                  controller: _location,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'Building, floor or room number',
                    prefixIcon: Icon(Icons.place_outlined, size: 20),
                  ),
                ),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional notes or purpose of the store',
                    prefixIcon: Icon(Icons.description_outlined, size: 20),
                  ),
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
                          label: Text(_staffDisplayName(staffId)),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () =>
                              setState(() => _storekeeperIds.remove(staffId)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Autocomplete<StaffOption>(
                  displayStringForOption: (staff) =>
                      '${staff.name} · ${staff.department} (#${staff.id})',
                  optionsBuilder: (textEditingValue) =>
                      _searchStaff(textEditingValue.text),
                  onSelected: (staff) {
                    setState(() => _storekeeperIds.add(staff.id));
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _staffSearchController?.clear();
                    });
                  },
                  fieldViewBuilder:
                      (context, searchController, focusNode, onFieldSubmitted) {
                        _staffSearchController = searchController;
                        return TextField(
                          controller: searchController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Add storekeeper',
                            hintText: 'Search staff by name or ID…',
                            prefixIcon: Icon(
                              Icons.person_search_outlined,
                              size: 20,
                            ),
                          ),
                        );
                      },
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
                  _busy ? 'Saving…' : (editing ? 'Update store' : 'Save store'),
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
    );
  }
}
