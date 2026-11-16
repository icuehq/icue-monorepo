import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_page.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_table.dart';
import 'package:inventory/src/ui/stock/issues/widgets/issue_request_card.dart';
import 'package:provider/provider.dart';

/// Issue requests of the branch (approvers and stock users), or of the store manager's stores.
class IssueRequestsPage extends StatefulWidget {
  const IssueRequestsPage({super.key});

  @override
  State<IssueRequestsPage> createState() => _IssueRequestsPageState();
}

class _IssueRequestsPageState extends State<IssueRequestsPage> {
  static const _statuses = {
    'pending': 'Pending',
    'approved': 'Approved',
    'partially_issued': 'Partially issued',
    'issued': 'Issued',
    'rejected': 'Rejected',
    'cancelled': 'Cancelled',
    'closed': 'Closed',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (mounted) await context.read<StockProvider>().issueRequests.load();
  }

  Future<void> _open(InventoryIssueRequest request) async {
    await context.push(
      '${InventoryRoutes.inventoryRequestDetail}?id=${request.id}',
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    String storeName(String storeId) =>
        inventoryProvider.stores
            .where((store) => store.id == storeId)
            .firstOrNull
            ?.name ??
        storeId;

    return PagedListPage<InventoryIssueRequest>(
      title: 'Issue Requests',
      state: stockProvider.issueRequests,
      statuses: _statuses,
      searchHint: 'Search by request number…',
      emptyIcon: Icons.assignment_outlined,
      emptyMessage: 'Requests raised by staff in your branch appear here.',
      onRefresh: _load,
      itemCard: (context, request) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: IssueRequestCard(
          request: request,
          storeName: storeName(request.storeId),
          itemName: stockProvider.itemName,
          onTap: () => _open(request),
        ),
      ),
      table: PagedListTable<InventoryIssueRequest>(
        title: 'Issue requests',
        state: stockProvider.issueRequests,
        statuses: _statuses,
        searchHint: 'Request number',
        rowKey: (request) => request.id,
        rowLabel: (request) => request.number,
        onOpen: _open,
        emptyMessage: 'Requests raised by staff in your branch appear here.',
        columns: [
          IcueTableColumn(
            id: 'number',
            label: 'Request',
            cellBuilder: (context, request) =>
                IcueTableCellText(request.number),
          ),
          IcueTableColumn(
            id: 'purpose',
            label: 'Purpose',
            flex: 3,
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
              child: InventoryStatusChip(request.status),
            ),
          ),
        ],
      ),
    );
  }
}
