import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:school_library/school_library.dart';

/// Add-book fields for the copies created with a new title: how many, and in which library.
class NewCopiesSection extends StatelessWidget {
  const NewCopiesSection({
    required this.copies,
    required this.libraries,
    required this.libraryId,
    required this.onLibraryChanged,
    super.key,
  });

  final TextEditingController copies;
  final List<SchoolLibrary> libraries;
  final String? libraryId;
  final ValueChanged<String?> onLibraryChanged;

  Widget _row(BuildContext context, List<Widget> fields) => context.isWide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 14),
            Expanded(child: fields[1]),
          ],
        )
      : Column(children: [fields[0], const SizedBox(height: 14), fields[1]]);

  @override
  Widget build(BuildContext context) {
    return FormSectionCard(
      title: 'Copies',
      icon: Icons.copy_rounded,
      children: [
        _row(context, [
          AppTextField(
            controller: copies,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final number = int.tryParse(value?.trim() ?? '');
              return number == null || number > 100
                  ? 'Enter 0 to 100 copies'
                  : null;
            },
            label: 'Number of copies *',
            hintText: 'e.g. 1',
            icon: Icons.copy_rounded,
            helperText:
                'Accession numbers are generated; 0 adds the title only',
          ),
          AppDropdown<String>(
            value: libraryId,
            items: [
              for (final library in libraries)
                DropdownMenuItem(value: library.id, child: Text(library.name)),
            ],
            onChanged: onLibraryChanged,
            validator: (value) =>
                value == null && (int.tryParse(copies.text.trim()) ?? 0) > 0
                ? 'Select a library'
                : null,
            icon: Icons.local_library_outlined,
            label: 'Library',
            helperText: libraries.isEmpty ? 'No active library found' : null,
          ),
        ]),
      ],
    );
  }
}
