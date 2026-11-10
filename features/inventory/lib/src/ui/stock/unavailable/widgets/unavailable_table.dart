import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Wide-screen damaged / expired stock: an [IcueClientTable] over the loaded
/// records. Rows the user may resolve open the resolve screen.
class UnavailableTable extends StatelessWidget {
  const UnavailableTable({
    required this.records,
    required this.loading,
    required this.errorMessage,
    required this.itemName,
    required this.storeName,
    required this.canOperate,
    required this.onResolve,
    required this.onRetry,
    super.key,
  });

  final List<InventoryUnavailable> records;
  final bool loading;
  final String? errorMessage;
  final String Function(String itemId) itemName;
  final String Function(String storeId) storeName;
  final bool canOperate;
  final void Function(InventoryUnavailable record) onResolve;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    bool canResolve(InventoryUnavailable record) =>
        canOperate && record.status != 'resolved';
    return IcueClientTable<InventoryUnavailable>(
      title: 'Damaged / expired stock',
      items: records,
      rowKey: (record) => record.id,
      rowLabel: (record) => itemName(record.itemId),
      status: IcueTableStatus.of(
        failed: errorMessage != null && records.isEmpty,
        loading: loading,
      ),
      errorMessage: errorMessage,
      onRetry: onRetry,
      initialPageSize: 25,
      searchHint: 'Search item, store or batch...',
      searchText: (record) =>
          '${itemName(record.itemId)} ${storeName(record.storeId)} '
          '${record.batchNumber ?? ''}',
      filters: [
        IcueClientFilter(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('open', 'Open'),
            IcueTableFilterOption('in_repair', 'In repair'),
            IcueTableFilterOption('resolved', 'Resolved'),
          ],
          matches: (record, status) => record.status == status,
        ),
      ],
      rowActions: (record) => canResolve(record)
          ? [
              IcueTableRowAction(
                label: 'Resolve',
                icon: Icons.build_outlined,
                inline: true,
                onPressed: onResolve,
              ),
            ]
          : const [],
      emptyTitle: 'No damaged or expired items',
      emptyMessage: 'Quarantined or damaged stock recorded during receipt, returns or audits appears here.',
      columns: [
        IcueTableColumn(
          id: 'item',
          label: 'Item',
          flex: 3,
          minWidth: 200,
          hideable: false,
          sortable: true,
          comparator: (record) => itemName(record.itemId).toLowerCase(),
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
          sortable: true,
          comparator: (record) => record.quantity,
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
          sortable: true,
          hideBelowWidth: 900,
          comparator: (record) => record.createdAt ?? DateTime(0),
          cellBuilder: (context, record) => IcueTableCellText(
            record.createdAt?.toNumericDate() ?? '—',
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
