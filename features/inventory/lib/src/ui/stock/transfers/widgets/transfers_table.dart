import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Wide-screen stock transfers: an [IcueClientTable] over the loaded transfers.
class TransfersTable extends StatelessWidget {
  const TransfersTable({
    required this.transfers,
    required this.loading,
    required this.errorMessage,
    required this.storeName,
    required this.nextAction,
    required this.onOpen,
    required this.onRetry,
    this.onNewTransfer,
    super.key,
  });

  final List<InventoryTransfer> transfers;
  final bool loading;
  final String? errorMessage;
  final String Function(String storeId) storeName;
  final String? Function(InventoryTransfer transfer) nextAction;
  final void Function(InventoryTransfer transfer) onOpen;
  final VoidCallback onRetry;
  final VoidCallback? onNewTransfer;

  @override
  Widget build(BuildContext context) {
    final newTransfer = onNewTransfer == null
        ? null
        : IcueTableAction(
            label: 'New transfer',
            icon: Icons.add_rounded,
            onPressed: onNewTransfer,
          );
    return IcueClientTable<InventoryTransfer>(
      title: 'Stock transfers',
      items: transfers,
      rowKey: (transfer) => transfer.id,
      rowLabel: (transfer) => transfer.number,
      status: IcueTableStatus.of(
        failed: errorMessage != null && transfers.isEmpty,
        loading: loading,
      ),
      errorMessage: errorMessage,
      onRetry: onRetry,
      initialPageSize: 25,
      searchHint: 'Search number or store...',
      searchText: (transfer) =>
          '${transfer.number} ${storeName(transfer.fromStoreId)} '
          '${storeName(transfer.toStoreId)}',
      filters: [
        IcueClientFilter(
          id: 'stage',
          label: 'Stage',
          options: const [
            IcueTableFilterOption('requested', 'Requested'),
            IcueTableFilterOption('in_transit', 'In transit'),
            IcueTableFilterOption('received', 'Received'),
          ],
          matches: (transfer, stage) => switch (stage) {
            'requested' => transfer.preDispatch,
            'in_transit' => transfer.inTransit,
            _ => transfer.status == stage,
          },
        ),
      ],
      onRowTap: onOpen,
      primaryAction: newTransfer,
      emptyTitle: 'No stock transfers found',
      emptyMessage: 'Initiate a new transfer between stores to move stock.',
      emptyAction: newTransfer,
      columns: [
        IcueTableColumn(
          id: 'number',
          label: 'Transfer',
          sortable: true,
          hideable: false,
          comparator: (transfer) => transfer.number,
          cellBuilder: (context, transfer) => IcueTableCellText(
            transfer.number.isEmpty ? 'Transfer' : transfer.number,
          ),
        ),
        IcueTableColumn(
          id: 'from',
          label: 'From',
          flex: 2,
          cellBuilder: (context, transfer) => IcueTableCellText(
            storeName(transfer.fromStoreId),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'to',
          label: 'To',
          flex: 2,
          cellBuilder: (context, transfer) => IcueTableCellText(
            storeName(transfer.toStoreId),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'lines',
          label: 'Lines',
          alignment: Alignment.centerRight,
          hideBelowWidth: 900,
          cellBuilder: (context, transfer) => IcueTableCellText(
            '${transfer.lineItems.length}',
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'created',
          label: 'Created',
          sortable: true,
          comparator: (transfer) => transfer.createdAt ?? DateTime(0),
          cellBuilder: (context, transfer) => IcueTableCellText(
            transfer.createdAt?.toNumericDate() ?? '—',
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          flex: 2,
          cellBuilder: (context, transfer) => IcueTableCellText(
            humanizeStatus(transfer.status),
            subtitle: nextAction(transfer),
          ),
        ),
      ],
    );
  }
}
