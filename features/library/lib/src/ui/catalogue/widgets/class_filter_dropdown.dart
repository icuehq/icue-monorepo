import 'package:flutter/material.dart';
import 'package:routes/routes.dart';

/// Catalogue filter: books meant for one ERP class (sections do not matter to books).
class ClassFilterDropdown extends StatelessWidget {
  const ClassFilterDropdown({
    required this.standards,
    required this.selectedClassId,
    required this.onChanged,
    super.key,
  });

  final List<Standards> standards;
  final int? selectedClassId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const label = Row(
      children: [
        Icon(Icons.school_outlined, size: 18),
        SizedBox(width: 8),
        Text('All classes'),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: standards.any((standard) => standard.id == selectedClassId)
              ? selectedClassId
              : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          hint: label,
          items: [
            const DropdownMenuItem<int?>(child: label),
            for (final standard in standards)
              DropdownMenuItem<int?>(
                value: standard.id,
                child: Text(standard.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
