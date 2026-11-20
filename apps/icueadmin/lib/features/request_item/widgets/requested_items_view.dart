import 'dart:async';

import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:icueadmin/features/request_item/widgets/requested_item_card.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Tab view showing the history of raised issue requests with status filters and details.
class RequestedItemsView extends StatefulWidget {
  const RequestedItemsView({required this.onRequestNew, super.key});

  final VoidCallback onRequestNew;

  @override
  State<RequestedItemsView> createState() => _RequestedItemsViewState();
}

class _RequestedItemsViewState extends State<RequestedItemsView> {
  final _searchController = TextEditingController();
  static const _statusOptions = [
    (null, 'All'),
    ('pending', 'Pending'),
    ('approved', 'Approved'),
    ('partially_issued', 'Partially issued'),
    ('issued', 'Issued'),
    ('rejected', 'Rejected'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stockProvider = context.read<StockProvider>();
      unawaited(stockProvider.issueRequests.load());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final issueRequests = context.read<StockProvider>().issueRequests;
    issueRequests.search = query.trim();
    unawaited(issueRequests.load());
  }

  void _onStatusSelected(String? status) {
    final issueRequests = context.read<StockProvider>().issueRequests;
    unawaited(issueRequests.setStatus(status));
  }

  Future<void> _refresh() async {
    await context.read<StockProvider>().issueRequests.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockProvider = context.watch<StockProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final issueRequests = stockProvider.issueRequests;
    final requests = issueRequests.pager.items;
    final isLoading = issueRequests.pager.loading;

    String storeName(String storeId) =>
        inventoryProvider.stores
            .where((store) => store.id == storeId)
            .firstOrNull
            ?.name ??
        '';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search & Status filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by request number...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  _onSearchChanged('');
                }
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                for (final (statusKey, label) in _statusOptions) ...[
                  FilterChip(
                    label: Text(label),
                    selected: issueRequests.status == statusKey,
                    labelStyle: TextStyle(
                      color: issueRequests.status == statusKey
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: issueRequests.status == statusKey
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 12,
                    ),
                    onSelected: (_) => _onStatusSelected(statusKey),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Expanded(
            child: isLoading && requests.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : requests.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: IcueEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: issueRequests.filtered
                            ? 'No matching requests'
                            : 'No requests yet',
                        message: issueRequests.filtered
                            ? 'Try clearing the search or status filter.'
                            : 'You have not submitted any item requests yet.',
                        actionLabel: issueRequests.filtered
                            ? 'Clear filters'
                            : 'Browse Catalog',
                        actionIcon: issueRequests.filtered
                            ? Icons.clear_rounded
                            : Icons.add_rounded,
                        onAction: () {
                          if (issueRequests.filtered) {
                            _searchController.clear();
                            issueRequests.search = '';
                            _onStatusSelected(null);
                          } else {
                            widget.onRequestNew();
                          }
                        },
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount:
                        requests.length + (issueRequests.pager.hasNext ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == requests.length) {
                        return IcueLoadMoreFooter.of(issueRequests.pager) ??
                            const SizedBox.shrink();
                      }
                      final request = requests[index];
                      return RequestedItemCard(
                        request: request,
                        storeName: storeName(request.storeId),
                        itemName: stockProvider.itemName,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
