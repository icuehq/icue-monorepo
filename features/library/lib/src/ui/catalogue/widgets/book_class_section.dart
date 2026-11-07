import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:routes/routes.dart';

/// Optional: the ERP classes a book is meant for. Empty means a general book for any class.
class BookClassSection extends StatelessWidget {
  const BookClassSection({
    required this.standards,
    required this.selectedIds,
    required this.onToggled,
    super.key,
  });

  final List<Standards> standards;
  final Set<int> selectedIds;
  final void Function(int classId, {required bool selected}) onToggled;

  @override
  Widget build(BuildContext context) => FormSectionCard(
    title: 'Classes',
    icon: Icons.school_outlined,
    children: [
      Text(
        'Optional. Leave empty for a general book any class can borrow.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final standard in standards)
            FilterChip(
              label: Text(standard.name),
              selected: selectedIds.contains(standard.id),
              onSelected: (selected) =>
                  onToggled(standard.id, selected: selected),
            ),
        ],
      ),
    ],
  );
}
