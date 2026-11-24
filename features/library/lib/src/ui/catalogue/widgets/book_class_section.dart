import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
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
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: 'Classes',
    icon: Icons.school_outlined,
    children: [
      // Tap-to-toggle chips: a search dropdown loses its menu when some browsers blur the field on click.
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final standard in standards)
            if (standard.isStudent)
              FilterChip(
                label: Text(standard.name),
                selected: selectedIds.contains(standard.id),
                onSelected: (picked) => onChanged({
                  for (final id in selectedIds)
                    if (id != standard.id) id,
                  if (picked) standard.id,
                }),
              ),
        ],
      ),
      Text(
        'Optional. Leave empty for a general book any class can borrow.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
