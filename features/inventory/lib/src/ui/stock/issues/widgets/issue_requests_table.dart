import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/issues/widgets/issue_request_widgets.dart';

/// Wide-screen issue requests: an [IcueClientTable] over the loaded requests.
/// The status filter reloads from Firestore, so the page owns it.
class IssueRequestsTable extends StatelessWidget {
  const IssueRequestsTable({
    required this.requests,
    required this.loading,
    required this.errorMessage,
    required this.status,
    required this.statuses,
    required this.onStatusChanged,
    required this.storeName,
    required this.onOpen,
    required this.onRetry,
    this.onNewRequest,
    super.key,
  });

  final List<InventoryIssueRequest> requests;
  final bool loading;
  final String? errorMessage;
  final String? status;
  final List<(String?, String)> statuses;
  final ValueChanged<String?> onStatusChanged;
  final String Function(String storeId) storeName;
  final void Function(InventoryIssueRequest request) onOpen;
  final VoidCallback onRetry;
  final VoidCallback? onNewRequest;

  @override
  Widget build(BuildContext context) {
    final newRequest = onNewRequest == null
        ? null
        : IcueTableAction(
            label: 'New request',
            icon: Icons.add_rounded,
            onPressed: onNewRequest,
          );
    return IcueClientTable<InventoryIssueRequest>(
      title: 'Issue requests',
      items: requests,
      rowKey: (request) => request.id,
      rowLabel: (request) => request.number,
      status: IcueTableStatus.of(
        failed: errorMessage != null && requests.isEmpty,
        loading: loading,
      ),
      errorMessage: errorMessage,
      onRetry: onRetry,
      initialPageSize: 25,
      searchHint: 'Search number, purpose or store...',
      searchText: (request) =>
          '${request.number} ${request.purpose} ${storeName(request.storeId)}',
      externalFilters: [
        IcueTableFilter(
          id: 'status',
          label: 'Status',
          options: [
            for (final (key, label) in statuses)
              if (key != null) IcueTableFilterOption(key, label),
          ],
          value: status,
          onChanged: onStatusChanged,
        ),
      ],
      externalFiltersActive: status != null,
      onClearExternalFilters: () => onStatusChanged(null),
      onRowTap: onOpen,
      primaryAction: newRequest,
      emptyTitle: 'No issue requests',
      emptyMessage: 'Submit an issue request to withdraw supplies or equipment from store stock.',
      emptyAction: newRequest,
      columns: [
        IcueTableColumn(
          id: 'number',
          label: 'Request',
          sortable: true,
          hideable: false,
          comparator: (request) => request.number,
          cellBuilder: (context, request) => IcueTableCellText(request.number),
        ),
        IcueTableColumn(
          id: 'purpose',
          label: 'Purpose',
          flex: 3,
          minWidth: 200,
          cellBuilder: (context, request) => IcueTableCellText(
            request.purpose,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'store',
          label: 'Store',
          flex: 2,
          cellBuilder: (context, request) => IcueTableCellText(
            storeName(request.storeId),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'raised',
          label: 'Raised',
          sortable: true,
          comparator: (request) => request.createdAt ?? DateTime(0),
          cellBuilder: (context, request) => IcueTableCellText(
            request.createdAt?.toNumericDate() ?? '—',
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          minWidth: 130,
          cellBuilder: (context, request) => Align(
            alignment: Alignment.centerLeft,
            child: IssueStatusPill(request.status),
          ),
        ),
      ],
    );
  }
}
