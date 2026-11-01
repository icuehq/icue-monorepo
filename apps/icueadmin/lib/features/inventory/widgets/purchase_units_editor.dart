import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';

/// Rows of `1 unit = factor stock units`.
class PurchaseUnitsEditor extends StatefulWidget {
  const PurchaseUnitsEditor({
    super.key,
    required this.units,
    required this.stockUnit,
    required this.initial,
    required this.onChanged,
  });

  final List<InventoryUnit> units;
  final String? stockUnit;
  final List<PurchaseUnit> initial;
  final ValueChanged<List<PurchaseUnit>> onChanged;

  @override
  State<PurchaseUnitsEditor> createState() => _PurchaseUnitsEditorState();
}

class _PurchaseUnitsEditorState extends State<PurchaseUnitsEditor> {
  late final List<PurchaseUnit> _rows = [...widget.initial];

  void _set(int index, PurchaseUnit? row) {
    setState(() {
      if (row == null) {
        if (index < _rows.length) {
          _rows.removeAt(index);
        }
      } else if (index >= _rows.length) {
        _rows.add(row);
      } else {
        _rows[index] = row;
      }
    });
    widget.onChanged(List.of(_rows));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = [
      for (final unit in widget.units)
        if (unit.code != widget.stockUnit) unit,
    ];
    final available = [
      for (final unit in options)
        if (!_rows.any((row) => row.unit == unit.code)) unit,
    ];
    final defaultUnit = available.isNotEmpty
        ? available.first
        : options.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase units (optional)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Packaging sizes (e.g. 1 Box = 10 Pcs)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: defaultUnit == null
                  ? null
                  : () => _set(
                      _rows.length,
                      PurchaseUnit(unit: defaultUnit.code, factor: 1),
                    ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add unit'),
            ),
          ],
        ),
        if (_rows.isNotEmpty) const SizedBox(height: 8),
        for (var index = 0; index < _rows.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              key: ValueKey('$index-${_rows[index].unit}'),
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _rows[index].unit,
                    decoration: const InputDecoration(
                      labelText: 'Purchase unit',
                      isDense: true,
                    ),
                    items: [
                      for (final unit in options)
                        DropdownMenuItem(
                          value: unit.code,
                          child: Text(unit.name),
                        ),
                    ],
                    onChanged: (value) => _set(
                      index,
                      PurchaseUnit(
                        unit: value ?? _rows[index].unit,
                        factor: _rows[index].factor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 105,
                  child: TextFormField(
                    initialValue: '${_rows[index].factor}',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [decimalInputFormatter],
                    decoration: InputDecoration(
                      labelText: '= x ${widget.stockUnit ?? 'stock'}',
                      isDense: true,
                    ),
                    validator: (value) {
                      final number = double.tryParse(value ?? '');
                      return number == null || number <= 0 ? '> 0' : null;
                    },
                    onChanged: (value) {
                      final number = double.tryParse(value);
                      if (number != null && number > 0) {
                        _rows[index] = PurchaseUnit(
                          unit: _rows[index].unit,
                          factor: number,
                        );
                        widget.onChanged(List.of(_rows));
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: 'Remove unit',
                  onPressed: () => _set(index, null),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
