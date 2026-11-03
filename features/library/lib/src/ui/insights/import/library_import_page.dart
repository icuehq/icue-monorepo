import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Import of library titles, copies and members.
class LibraryImportPage extends StatelessWidget {
  const LibraryImportPage({super.key});

  static const _hints = {
    'catalogue': 'Authors and keywords separated by ";". categoryCode of an existing category. Existing titles are rejected.',
    'copies': 'One opening-stock acquisition per row: isbn13 of an existing title, libraryCode, quantity (default 1). Accession numbers are generated.',
    'members': 'memberType student or teacher; libraryCodes separated by ";"; dates yyyy-mm-dd. Existing members are rejected.',
  };

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryProvider>();
    return CsvImportScreen(
      kinds: [
        for (final entry in libraryImportPerms.entries)
          ImportKind(
            type: entry.key,
            columns: libraryImportColumns[entry.key]!,
            hint: _hints[entry.key]!,
            canImport: library.access.can(entry.value),
          ),
      ],
      run: library.importRows,
      errorMessage: () => library.errorMessage,
    );
  }
}
