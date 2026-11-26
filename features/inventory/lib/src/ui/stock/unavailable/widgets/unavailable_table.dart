import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_table.dart';

/// Wide-screen damaged / expired stock over the provider's [ListState]: status filter,
/// item-name search and paging are server queries. Rows the user may resolve open the resolve screen.
class UnavailableTable extends StatelessWidget {
  const UnavailableTable({
    required this.state,
    required this.statuses,
    required this.itemName,
    required this.storeName,
    required this.canOperate,
    required this.onResolve,
    super.key,
  });

  final ListState<InventoryUnavailable> state;
  final Map<String, String> statuses;
  final String Function(String itemId) itemName;
  final String Function(String storeId) storeName;
  final bool canOperate;
  final void Function(InventoryUnavailable record) onResolve;

  @override
  Widget build(BuildContext context) {
    bool canResolve(InventoryUnavailable record) =>
        canOperate && record.status != 'resolved';
    return PagedListTable<InventoryUnavailable>(
      title: 'Damaged / expired stock',
      state: state,
      statuses: statuses,
      searchHint: 'Item name',
      rowKey: (record) => record.id,
      rowLabel: (record) => itemName(record.itemId),
      onOpen: (record) {
        if (canResolve(record)) onResolve(record);
      },
      emptyMessage: 'Quarantined or damaged stock recorded during receipt, returns or audits appears here.',
      columns: [
        IcueTableColumn(
          id: 'item',
          label: 'Item',
          flex: 3,
          minWidth: 200,
          hideable: false,
          cellBuilder: (context, record) => IcueTableCellText(
            itemName(record.itemId),
            subtitle: record.batchNumber == null
                ? null
                : 'Batch ${record.batchNumber}',
          ),
        ),
        IcueTableColumn(
          id: 'store',
          label: 'Store',
          flex: 2,
          cellBuilder: (context, record) => IcueTableCellText(
            storeName(record.storeId),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'quantity',
          label: 'Quantity',
          alignment: Alignment.centerRight,
          cellBuilder: (context, record) => IcueTableCellText(
            record.quantity.toQuantityText(),
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'bucket',
          label: 'Type',
          cellBuilder: (context, record) => IcueTableCellText(
            humanizeStatus(record.bucket ?? record.reason),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          flex: 2,
          cellBuilder: (context, record) => IcueTableCellText(
            humanizeStatus(record.status),
            subtitle: record.resolution == null
                ? null
                : humanizeStatus(record.resolution!),
          ),
        ),
        IcueTableColumn(
          id: 'recorded',
          label: 'Recorded',
          hideBelowWidth: 900,
          cellBuilder: (context, record) => IcueTableCellText(
            record.createdAt?.toIndianTime().toNumericDate() ?? '—',
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'remarks',
          label: 'Remarks',
          flex: 2,
          hideBelowWidth: 1100,
          cellBuilder: (context, record) => IcueTableCellText(
            record.remarks ?? '—',
            style: IcueTableStyle.of(context).muted,
          ),
        ),
      ],
    );
  }
}
