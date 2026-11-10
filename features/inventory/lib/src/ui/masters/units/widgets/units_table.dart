import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/masters/units/widgets/unit_dialog.dart';

/// Wide-screen units list: an [IcueClientTable] over the loaded units.
class UnitsTable extends StatelessWidget {
  const UnitsTable({required this.units, required this.canEdit, super.key});

  final List<InventoryUnit> units;
  final bool canEdit;

  @override
  Widget build(BuildContext context) => IcueClientTable<InventoryUnit>(
    title: 'Units of measurement',
    items: units,
    rowKey: (unit) => unit.code,
    rowLabel: (unit) => unit.name,
    searchHint: 'Search name or code...',
    searchText: (unit) => '${unit.name} ${unit.code}',
    initialPageSize: 25,
    onRowTap: canEdit ? (unit) => UnitDialog.show(context, unit: unit) : null,
    primaryAction: canEdit
        ? IcueTableAction(
            label: 'Unit',
            icon: Icons.add_rounded,
            onPressed: () => UnitDialog.show(context),
          )
        : null,
    rowActions: (unit) => canEdit
        ? [
            IcueTableRowAction(
              label: 'Edit',
              icon: Icons.edit_outlined,
              inline: true,
              onPressed: (row) => UnitDialog.show(context, unit: row),
            ),
          ]
        : const [],
    columns: [
      IcueTableColumn(
        id: 'name',
        label: 'Unit',
        flex: 3,
        minWidth: 200,
        sortable: true,
        comparator: (unit) => unit.name.toLowerCase(),
        hideable: false,
        cellBuilder: (context, unit) => IcueTableCellText(unit.name),
      ),
      IcueTableColumn(
        id: 'code',
        label: 'Code',
        sortable: true,
        comparator: (unit) => unit.code.toLowerCase(),
        cellBuilder: (context, unit) => IcueTableCellText(
          unit.code,
          style: IcueTableStyle.of(context).secondary,
        ),
      ),
    ],
  );
}
