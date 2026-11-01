import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/csv_import_screen.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Import of inventory master data (categories, stores, items, vendors).
class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  static const _hints = {
    'categories': 'Existing codes are rejected, not updated.',
    'stores': 'Existing codes are rejected, not updated.',
    'items': 'Items need categoryCode of an existing category. Existing codes are rejected, not updated.',
    'vendors': 'Existing codes are rejected, not updated.',
  };

  @override
  Widget build(BuildContext context) {
    final access = context.read<InventoryProvider>().access;
    final insights = context.read<InsightsProvider>();
    return CsvImportScreen(
      kinds: [
        for (final entry in importPermissions.entries)
          ImportKind(
            type: entry.key,
            columns: importColumns[entry.key]!,
            hint: _hints[entry.key]!,
            canImport: access.can(entry.value),
          ),
      ],
      run: (type, importId, rows) => insights.act('inventory-import-run', {
        'importId': importId,
        'type': type,
        'rows': rows,
      }),
      errorMessage: () => insights.errorMessage,
    );
  }
}
