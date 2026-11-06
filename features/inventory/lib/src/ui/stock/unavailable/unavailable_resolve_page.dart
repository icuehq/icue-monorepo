import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

typedef _Choice = ({
  String key,
  String title,
  String subtitle,
  IconData icon,
  Color color,
});

const List<_Choice> _choices = [
  (
    key: 'restore',
    title: 'Return to usable stock',
    subtitle: 'Restores quantity to active store inventory after inspection',
    icon: Icons.check_circle_outline_rounded,
    color: Colors.green,
  ),
  (
    key: 'repair',
    title: 'Send for repair',
    subtitle: 'Moves to in-repair quarantine until fixed',
    icon: Icons.build_outlined,
    color: Colors.blue,
  ),
  (
    key: 'vendor_return',
    title: 'Return to vendor',
    subtitle: 'Send back to vendor for replacement or credit',
    icon: Icons.assignment_return_outlined,
    color: Colors.purple,
  ),
  (
    key: 'write_off',
    title: 'Write off',
    subtitle: 'Deduct from books as loss',
    icon: Icons.money_off_outlined,
    color: Colors.orange,
  ),
  (
    key: 'dispose',
    title: 'Dispose / Scrap',
    subtitle: 'Permanently destroy or discard the physical item',
    icon: Icons.delete_outline_rounded,
    color: Colors.red,
  ),
  (
    key: 'other',
    title: 'Other resolution',
    subtitle: 'Describe the resolution in the note',
    icon: Icons.more_horiz_rounded,
    color: Colors.grey,
  ),
];

/// Resolves one damaged / expired stock entry (FRS 10.12).
class UnavailableResolvePage extends StatefulWidget {
  const UnavailableResolvePage({required this.unavailableId, super.key});

  final String unavailableId;

  @override
  State<UnavailableResolvePage> createState() => _UnavailableResolvePageState();
}

class _UnavailableResolvePageState extends State<UnavailableResolvePage> {
  final _remarks = TextEditingController();
  final _requestId = newRequestId();
  String? _selected;
  var _busy = false;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  /// Destructive choices need a second confirmation.
  Future<bool> _confirm(_Choice choice, InventoryUnavailable item) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${choice.title}?'),
          content: Text(
            'This will permanently resolve ${item.quantity.toQuantityText()} units as ${choice.title}. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _submit(_Choice choice, InventoryUnavailable item) async {
    if (choice.key == 'other' && _remarks.text.trim().isEmpty) {
      showMessage(context, 'Describe the resolution');
      return;
    }
    if ((choice.key == 'dispose' || choice.key == 'write_off') &&
        !await _confirm(choice, item)) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    await stockSubmit(
      context,
      (stockProvider) => stockProvider.act('inventory-unavailable-resolve', {
        'id': item.id,
        'resolution': choice.key,
        'remarks': _remarks.text.trim(),
      }, requestId: _requestId),
      done: 'Resolution recorded',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockProvider = context.watch<StockProvider>();
    final item = stockProvider.unavailable
        .where((entry) => entry.id == widget.unavailableId)
        .firstOrNull;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resolve Stock')),
        body: Center(
          child: stockProvider.isLoading
              ? const CircularProgressIndicator()
              : const Text('Entry not found'),
        ),
      );
    }

    final storeName =
        stockProvider.allStores
            .where((store) => store.id == item.storeId)
            .firstOrNull
            ?.name ??
        item.storeId;
    final choices = [
      for (final choice in _choices)
        if (choice.key != 'repair' ||
            (item.status == 'open' && item.bucket == 'damaged'))
          choice,
    ];
    final selected = choices
        .where((choice) => choice.key == _selected)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Resolve Stock')),
      body: CenteredBody(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stockProvider.itemName(item.itemId),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Store: $storeName'
                      '${item.batchNumber == null ? '' : ' · Batch ${item.batchNumber}'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.quantity.toQuantityText()} units · '
                      '${humanizeStatus(item.bucket ?? item.reason)} · '
                      '${humanizeStatus(item.status)}'
                      '${item.createdAt == null ? '' : ' · ${item.createdAt!.toNumericDate()}'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(item.remarks!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'What should happen to this stock?',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (value) {
                if (!_busy) setState(() => _selected = value);
              },
              child: Column(
                children: [
                  for (final choice in choices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _selected == choice.key
                                ? choice.color
                                : theme.colorScheme.outlineVariant,
                            width: _selected == choice.key ? 2 : 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: choice.key,
                          secondary: Icon(choice.icon, color: choice.color),
                          title: Text(
                            choice.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(choice.subtitle),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _remarks,
              enabled: !_busy,
              maxLength: 500,
              maxLines: 3,
              label: _selected == 'other'
                  ? 'Resolution note (required)'
                  : 'Resolution note (optional)',
              hintText: 'e.g. Broken packaging replaced by supplier',
              icon: Icons.edit_note_rounded,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: FilledButton.icon(
              onPressed: selected == null || _busy
                  ? null
                  : () => _submit(selected, item),
              icon: const Icon(Icons.check_rounded),
              label: Text(selected?.title ?? 'Select an action'),
            ),
          ),
        ),
      ),
    );
  }
}
