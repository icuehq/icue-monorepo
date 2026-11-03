import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/stock_ui.dart';
import 'package:provider/provider.dart';

class UnavailableResolveSheet extends StatefulWidget {
  const UnavailableResolveSheet({
    required this.unavailable,
    required this.storeName,
    super.key,
  });

  final InventoryUnavailable unavailable;
  final String storeName;

  @override
  State<UnavailableResolveSheet> createState() =>
      _UnavailableResolveSheetState();
}

class _UnavailableResolveSheetState extends State<UnavailableResolveSheet> {
  final _remarks = TextEditingController();
  final _requestId = newRequestId();
  var _busy = false;

  static const _choices = [
    (
      key: 'restore',
      title: 'Return to usable stock',
      subtitle:
          'Restores quantity back to active store inventory after inspection',
      icon: Icons.check_circle_outline_rounded,
      color: Colors.green,
    ),
    (
      key: 'repair',
      title: 'Send for repair',
      subtitle: 'Moves to in_repair quarantine until fixed',
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
      subtitle: 'Permanently destroy or discard physical item',
      icon: Icons.delete_outline_rounded,
      color: Colors.red,
    ),
    (
      key: 'other',
      title: 'Other resolution',
      subtitle: 'Specify custom resolution in note below',
      icon: Icons.more_horiz_rounded,
      color: Colors.grey,
    ),
  ];

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _executeResolution(String choiceKey, String choiceTitle) async {
    // Show confirmation for permanent loss actions
    if (choiceKey == 'dispose' || choiceKey == 'write_off') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('$choiceTitle?'),
          content: Text(
            'This will permanently resolve ${formatQuantity(widget.unavailable.quantity)} units as $choiceTitle. This action cannot be undone.',
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
      );
      if (confirm != true || !mounted) return;
    }

    setState(() => _busy = true);
    await stockSubmit(
      context,
      (stockProvider) => stockProvider.act('inventory-unavailable-resolve', {
        'id': widget.unavailable.id,
        'resolution': choiceKey,
        'remarks': _remarks.text.trim(),
      }, requestId: _requestId),
      done: 'Resolution recorded',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.unavailable;
    final stockProvider = context.read<StockProvider>();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resolve Unavailable Stock',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${stockProvider.itemName(item.itemId)} · ${formatQuantity(item.quantity)} units',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  humanizeStatus(item.bucket ?? item.reason),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _remarks,
            decoration: const InputDecoration(
              labelText: 'Resolution note / reason',
              hintText: 'e.g. Broken packaging replaced by supplier',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Action',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final choice in _choices)
            if (choice.key != 'repair' ||
                (item.status == 'open' && item.bucket == 'damaged'))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    enabled: !_busy,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: choice.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(choice.icon, size: 20, color: choice.color),
                    ),
                    title: Text(
                      choice.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      choice.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _executeResolution(choice.key, choice.title),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
