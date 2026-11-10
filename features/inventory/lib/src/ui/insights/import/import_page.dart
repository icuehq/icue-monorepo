import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Import of inventory master data (categories, items, vendors).
class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  static const _hints = {
    'categories': 'Existing codes are rejected, not updated.',
    'items': 'Items need categoryCode of an existing category. Existing codes are rejected, not updated.',
    'vendors': 'Existing codes are rejected, not updated.',
  };

  @override
  Widget build(BuildContext context) {
    final access = context.read<InventoryProvider>().access;
    final insights = context.read<InsightsProvider>();
    return IcueCsvImportScreen(
      kinds: [
        for (final entry in importPermissions.entries)
          IcueImportKind(
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
