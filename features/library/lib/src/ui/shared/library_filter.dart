import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// The Library filter of a phone layout: one dropdown above the list, "All libraries" when [value] is null.
/// Hidden with a single library; a librarian (restricted) has no "All libraries" entry.
class LibraryFilterDropdown extends StatelessWidget {
  const LibraryFilterDropdown({
    required this.libraries,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<SchoolLibrary> libraries;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (libraries.length <= 1) return const SizedBox.shrink();
    final restricted = context.read<LibraryProvider>().restricted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: DropdownButtonFormField<String?>(
        initialValue: restricted ? (value ?? libraries.first.id) : value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Library',
          prefixIcon: Icon(Icons.local_library_outlined, size: 18),
          isDense: true,
        ),
        items: [
          if (!restricted) const DropdownMenuItem(child: Text('All libraries')),
          for (final schoolLibrary in libraries)
            DropdownMenuItem(
              value: schoolLibrary.id,
              child: Text(schoolLibrary.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// The Library filter of a wide table: every library, whatever the rows loaded so far.
/// Empty with a single library: there is nothing to filter by.
List<IcueTableFilter> libraryTableFilter(
  List<SchoolLibrary> libraries,
  String? value,
  ValueChanged<String?> onChanged,
) => [
  if (libraries.length > 1)
    IcueTableFilter(
      id: 'library',
      label: 'Library',
      options: [
        for (final schoolLibrary in libraries)
          IcueTableFilterOption(schoolLibrary.id, schoolLibrary.name),
      ],
      value: value,
      onChanged: onChanged,
    ),
];
