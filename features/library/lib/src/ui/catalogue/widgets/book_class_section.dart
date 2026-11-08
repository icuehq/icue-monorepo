import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:routes/routes.dart';

/// Optional: the ERP classes a book is meant for. Empty means a general book for any class.
class BookClassSection extends StatelessWidget {
  const BookClassSection({
    required this.standards,
    required this.selectedIds,
    required this.onChanged,
    super.key,
  });

  final List<Standards> standards;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) => FormSectionCard(
    title: 'Classes',
    icon: Icons.school_outlined,
    children: [
      AppMultiAutocomplete<Standards>(
        options: standards,
        selected: [
          for (final standard in standards)
            if (selectedIds.contains(standard.id)) standard,
        ],
        labelOf: (standard) => standard.name,
        onChanged: (picked) =>
            onChanged({for (final standard in picked) standard.id}),
        label: 'Classes',
        hintText: 'Search a class',
        helperText:
            'Optional. Leave empty for a general book any class can borrow.',
      ),
    ],
  );
}
