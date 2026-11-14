import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// The Library filter of a phone layout: one dropdown above the list, "All libraries" when [value] is null.
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Library',
        prefixIcon: Icon(Icons.local_library_outlined, size: 18),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(child: Text('All libraries')),
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

/// The Library filter of a wide table: every library, whatever the rows loaded so far.
IcueTableFilter libraryTableFilter(
  List<SchoolLibrary> libraries,
  String? value,
  ValueChanged<String?> onChanged,
) => IcueTableFilter(
  id: 'library',
  label: 'Library',
  options: [
    for (final schoolLibrary in libraries)
      IcueTableFilterOption(schoolLibrary.id, schoolLibrary.name),
  ],
  value: value,
  onChanged: onChanged,
);
