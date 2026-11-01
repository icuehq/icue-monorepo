import 'package:flutter/material.dart';
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

  final List<InvUnit> units;
  final String? stockUnit;
  final List<PurchaseUnit> initial;
  final ValueChanged<List<PurchaseUnit>> onChanged;

  @override
  State<PurchaseUnitsEditor> createState() => _PurchaseUnitsEditorState();
}

class _PurchaseUnitsEditorState extends State<PurchaseUnitsEditor> {
  late final List<PurchaseUnit> _rows = [...widget.initial];

  void _set(int i, PurchaseUnit? row) {
    setState(() => row == null ? _rows.removeAt(i) : _rows[i] = row);
    widget.onChanged(List.of(_rows));
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final u in widget.units)
        if (u.code != widget.stockUnit) u,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Purchase units (optional)')),
            TextButton.icon(
              onPressed: options.isEmpty
                  ? null
                  : () => _set(
                      _rows.length,
                      PurchaseUnit(unit: options.first.code, factor: 1),
                    ),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        for (var i = 0; i < _rows.length; i++)
          Row(
            key: ValueKey('$i-${_rows[i].unit}'),
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _rows[i].unit,
                  items: [
                    for (final u in options)
                      DropdownMenuItem(value: u.code, child: Text(u.name)),
                  ],
                  onChanged: (v) => _set(
                    i,
                    PurchaseUnit(
                      unit: v ?? _rows[i].unit,
                      factor: _rows[i].factor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: '${_rows[i].factor}',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'x ${widget.stockUnit ?? 'stock'}',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || n <= 0 ? '> 0' : null;
                  },
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null && n > 0) {
                      _rows[i] = PurchaseUnit(unit: _rows[i].unit, factor: n);
                      widget.onChanged(List.of(_rows));
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _set(i, null),
              ),
            ],
          ),
      ],
    );
  }
}
