import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
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
            IcueButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(dialogContext, false),
              variant: IcueButtonVariant.ghost,
            ),
            IcueButton(
              label: 'Confirm',
              onPressed: () => Navigator.pop(dialogContext, true),
              variant: IcueButtonVariant.destructive,
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

    final wide = MediaQuery.sizeOf(context).width >= IcueBreakpoints.wide;

    final summary = _Summary(
      item: item,
      storeName: storeName,
      name: stockProvider.itemName(item.itemId),
    );
    final options = _Options(
      choices: choices,
      selected: _selected,
      enabled: !_busy,
      onChanged: (value) => setState(() => _selected = value),
    );
    final note = IcueTextField(
      controller: _remarks,
      enabled: !_busy,
      maxLength: 500,
      maxLines: 3,
      label: _selected == 'other'
          ? 'Resolution note (required)'
          : 'Resolution note (optional)',
      hintText: 'e.g. Broken packaging replaced by supplier',
      icon: Icons.edit_note_rounded,
    );
    final submit = IcueButton(
      label: selected?.title ?? 'Select an action',
      onPressed: selected == null || _busy
          ? null
          : () => _submit(selected, item),
      leadingIcon: Icons.check_rounded,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Resolve Stock')),
      body: IcueCenteredBody(
        child: wide
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 380,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summary,
                          const SizedBox(height: 16),
                          note,
                          const SizedBox(height: 8),
                          submit,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: options),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  summary,
                  const SizedBox(height: 20),
                  options,
                  const SizedBox(height: 12),
                  note,
                ],
              ),
      ),
      bottomNavigationBar: wide
          ? null
          : Material(
              elevation: 8,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: submit,
                ),
              ),
            ),
    );
  }
}

/// Entry details as labelled facts instead of one dense line.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.item,
    required this.storeName,
    required this.name,
  });

  final InventoryUnavailable item;
  final String storeName;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget fact(String label, String value, {Color? color}) => SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                fact(
                  'Quantity',
                  '${item.quantity.toQuantityText()} units',
                  color: scheme.error,
                ),
                fact('Type', humanizeStatus(item.bucket ?? item.reason)),
                fact('Status', humanizeStatus(item.status)),
                fact('Store', storeName),
                if (item.batchNumber != null) fact('Batch', item.batchNumber!),
                if (item.createdAt != null)
                  fact('Recorded', item.createdAt!.toNumericDate()),
              ],
            ),
            if (item.remarks != null && item.remarks!.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                'Remarks',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(item.remarks!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Resolution choices: one column on phones, two when the pane is wide enough.
class _Options extends StatelessWidget {
  const _Options({
    required this.choices,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<_Choice> choices;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What should happen to this stock?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final columns = constraints.maxWidth >= 560 ? 2 : 1;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final choice in choices)
                  SizedBox(
                    width: width,
                    child: _OptionTile(
                      choice: choice,
                      isSelected: selected == choice.key,
                      onTap: enabled ? () => onChanged(choice.key) : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.choice,
    required this.isSelected,
    required this.onTap,
  });

  final _Choice choice;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);
    return Material(
      color: isSelected
          ? choice.color.withValues(alpha: 0.08)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: isSelected ? choice.color : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: choice.color.withValues(alpha: 0.12),
                child: Icon(choice.icon, color: choice.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      choice.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      choice.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: choice.color),
            ],
          ),
        ),
      ),
    );
  }
}
