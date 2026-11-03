import 'package:flutter/material.dart';

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

String staffDisplayName(int staffId) {
  for (final staff in _sampleStaffList) {
    if (staff.id == staffId) return '${staff.name} (#$staffId)';
  }
  return 'Staff #$staffId';
}

/// Name/department/ID search over ERP people. A typed number is always
/// accepted as an ID so people missing from the lookup can still be chosen.
class PersonSearchField extends StatefulWidget {
  const PersonSearchField({
    required this.label,
    required this.onSelected,
    this.hint = 'Search by name or ID…',
    this.exclude = const {},
    this.clearOnSelect = false,
    super.key,
  });

  final String label;
  final String hint;
  final Set<int> exclude;
  final bool clearOnSelect;
  final ValueChanged<StaffOption> onSelected;

  @override
  State<PersonSearchField> createState() => _PersonSearchFieldState();
}

class _PersonSearchFieldState extends State<PersonSearchField> {
  TextEditingController? _controller;

  Iterable<StaffOption> _search(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];
    final matches = _sampleStaffList.where((staff) {
      return !widget.exclude.contains(staff.id) &&
          (staff.name.toLowerCase().contains(trimmed) ||
              staff.department.toLowerCase().contains(trimmed) ||
              staff.id.toString().contains(trimmed));
    }).toList();
    final numericId = int.tryParse(trimmed);
    if (numericId != null &&
        !widget.exclude.contains(numericId) &&
        !matches.any((staff) => staff.id == numericId)) {
      matches.add(
        StaffOption(id: numericId, name: 'ID #$numericId', department: 'ERP'),
      );
    }
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<StaffOption>(
      displayStringForOption: (staff) =>
          '${staff.name} · ${staff.department} (#${staff.id})',
      optionsBuilder: (value) => _search(value.text),
      onSelected: (staff) {
        widget.onSelected(staff);
        if (widget.clearOnSelect) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _controller?.clear();
          });
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _controller = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.person_search_outlined, size: 20),
          ),
        );
      },
    );
  }
}
