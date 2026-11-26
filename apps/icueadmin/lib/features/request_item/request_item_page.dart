import 'dart:async';

import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:icueadmin/features/request_item/models/request_item_line.dart';
import 'package:icueadmin/features/request_item/widgets/request_bottom_bar.dart';
import 'package:icueadmin/features/request_item/widgets/request_item_card.dart';
import 'package:icueadmin/features/request_item/widgets/request_search_bar.dart';
import 'package:icueadmin/features/request_item/widgets/request_summary_panel.dart';
import 'package:icueadmin/features/request_item/widgets/request_variant_dialog.dart';
import 'package:icueadmin/features/request_item/widgets/requested_items_view.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Lists every inventory item (across all stores) so staff/admins can pick items
/// and raise requests, and review previously submitted requests.
class RequestItemPage extends StatefulWidget {
  const RequestItemPage({super.key});

  @override
  State<RequestItemPage> createState() => _RequestItemPageState();
}

class _RequestItemPageState extends State<RequestItemPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _purposeController = TextEditingController();
  final _lines = <RequestItemLine>[];
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inventory = context.read<InventoryProvider>();
      if (inventory.stores.isEmpty) inventory.loadMasters();
      inventory.loadItems(search: '', clearCategory: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _purposeController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
    context.read<InventoryProvider>().loadItems(
      search: query.trim(),
      clearCategory: true,
    );
  }

  Future<void> _add(InventoryItem item) async {
    final variants = (await context.read<InventoryProvider>().variants(item.id))
        .where((variant) => variant.active)
        .toList();
    if (!mounted) return;

    InventoryVariant? chosenVariant;
    if (variants.length == 1) {
      chosenVariant = variants.first;
    } else if (variants.length > 1) {
      chosenVariant = await RequestVariantDialog.show(
        context,
        item: item,
        variants: variants,
      );
      if (chosenVariant == null || !mounted) return;
    }

    final key = '${item.id}|${chosenVariant?.id}';
    final existingIndex = _lines.indexWhere((line) => line.key == key);
    if (existingIndex >= 0) {
      setState(() => _lines[existingIndex].increment());
      showMessage(context, 'Increased quantity for ${item.name}');
      return;
    }

    setState(() {
      _lines.add(RequestItemLine(item: item, variant: chosenVariant));
    });
    showMessage(context, 'Added ${item.name} to request');
  }

  void _removeLine(RequestItemLine line) {
    setState(() {
      _lines.remove(line);
      line.disposeLater();
    });
  }

  void _clearAllLines() {
    setState(() {
      for (final line in _lines) {
        line.disposeLater();
      }
      _lines.clear();
    });
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      return showMessage(context, 'Select at least one item');
    }
    if (_purposeController.text.trim().isEmpty) {
      return showMessage(context, 'Enter the purpose of the request');
    }
    for (final line in _lines) {
      if (line.quantity <= 0) {
        return showMessage(
          context,
          'Enter a valid quantity for ${line.item.name}',
        );
      }
    }

    final stockProvider = context.read<StockProvider>();
    final requesterName = context.read<AuthProvider>().user?.name;
    setState(() => _isSubmitting = true);

    // One request per store and top-level category: each category has its own approvers.
    final byStoreAndCategory = <(String, String), List<RequestItemLine>>{};
    for (final line in _lines) {
      byStoreAndCategory
          .putIfAbsent((line.item.storeId, line.item.categoryId), () => [])
          .add(line);
    }

    final numbers = <String>[];
    for (final MapEntry(key: (storeId, categoryId), value: storeLines)
        in byStoreAndCategory.entries) {
      final result = await stockProvider.act('inventory-issueRequest-submit', {
        'storeId': storeId,
        'categoryId': categoryId,
        'purpose': _purposeController.text.trim(),
        'requesterName': ?requesterName,
        'lineItems': [
          for (final line in storeLines)
            {
              'itemId': line.item.id,
              'variantId': ?line.variant?.id,
              'quantity': line.quantity,
            },
        ],
      });

      if (!mounted) return;
      if (result == null) {
        setState(() => _isSubmitting = false);
        return IcueToast.error(
          context,
          stockProvider.errorMessage ?? 'Could not raise the request',
        );
      }
      numbers.add(result['number'] as String);
      setState(() {
        for (final line in storeLines) {
          line.disposeLater();
        }
        _lines.removeWhere(storeLines.contains);
      });
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _purposeController.clear();
    showMessage(context, 'Request raised · ${numbers.join(', ')}');
    unawaited(stockProvider.issueRequests.load());
    _tabController.animateTo(1);
  }

  void _openReviewSheet() {
    final inventory = context.read<InventoryProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return AnimatedPadding(
            padding: EdgeInsets.only(bottom: bottomInset),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Flexible(
                    child: RequestSummaryPanel(
                      lines: _lines,
                      purposeController: _purposeController,
                      isSubmitting: _isSubmitting,
                      onSubmit: () async {
                        if (_purposeController.text.trim().isEmpty) {
                          showMessage(
                            sheetContext,
                            'Enter the purpose of the request',
                          );
                          return;
                        }
                        Navigator.of(sheetContext).pop();
                        await _submit();
                      },
                      onRemoveLine: (line) {
                        _removeLine(line);
                        setSheetState(() {});
                        if (_lines.isEmpty) Navigator.of(sheetContext).pop();
                      },
                      onClearAll: () {
                        _clearAllLines();
                        Navigator.of(sheetContext).pop();
                      },
                      onQuantityChanged: () => setSheetState(() {}),
                      storeName: (id) => inventory.storeName(id) ?? '',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = context.isWide;
    final inventory = context.watch<InventoryProvider>();
    final roleIds = context.watch<AuthProvider>().roleIds;
    final items = inventory.items
        .where(
          (item) =>
              item.active &&
              (inventory.category(item.categoryId)?.canRequest(roleIds) ??
                  false),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Items'),
        actions: [
          if (!isWide && _lines.isNotEmpty && _tabController.index == 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Review selected items',
                icon: Badge.count(
                  count: _lines.length,
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                onPressed: _openReviewSheet,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.storefront_outlined, size: 20),
              text: 'Browse Catalog',
            ),
            Tab(
              icon: Icon(Icons.receipt_long_outlined, size: 20),
              text: 'My Requests',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          IcueCenteredBody(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Catalog Column
                        Expanded(
                          flex: 6,
                          child: _buildCatalog(context, inventory, items),
                        ),
                        const SizedBox(width: 20),
                        // Summary Column
                        SizedBox(
                          width: 380,
                          child: RequestSummaryPanel(
                            lines: _lines,
                            purposeController: _purposeController,
                            isSubmitting: _isSubmitting,
                            onSubmit: _submit,
                            onRemoveLine: _removeLine,
                            onClearAll: _clearAllLines,
                            onQuantityChanged: () => setState(() {}),
                            storeName: (id) => inventory.storeName(id) ?? '',
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned.fill(
                          bottom: _lines.isNotEmpty ? 72 : 0,
                          child: _buildCatalog(context, inventory, items),
                        ),
                        if (_lines.isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: RequestBottomBar(
                              itemCount: _lines.length,
                              onReview: _openReviewSheet,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          IcueCenteredBody(
            child: RequestedItemsView(
              onRequestNew: () => _tabController.animateTo(0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalog(
    BuildContext context,
    InventoryProvider inventory,
    List<InventoryItem> items,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleItems = query.isEmpty
        ? items
        : items.where((item) {
            final name = item.name.toLowerCase();
            final cat =
                inventory.category(item.categoryId)?.name.toLowerCase() ?? '';
            return name.contains(query) || cat.contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RequestSearchBar(
          controller: _searchController,
          onSearchChanged: _onSearchChanged,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: inventory.itemsLoading && visibleItems.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : visibleItems.isEmpty
              ? IcueEmptyState.noResults(
                  title: 'No items match your search',
                  message: 'Try searching with a different item name.',
                  onAction: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMultiColumn = constraints.maxWidth >= 600;
                    if (isMultiColumn) {
                      final columnWidth = (constraints.maxWidth - 12) / 2;
                      return ListView(
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final item in visibleItems)
                                SizedBox(
                                  width: columnWidth,
                                  child: _buildItemCard(item, inventory),
                                ),
                            ],
                          ),
                          if (inventory.hasMoreItems) _buildLoadMore(inventory),
                        ],
                      );
                    }
                    return ListView.separated(
                      itemCount:
                          visibleItems.length +
                          (inventory.hasMoreItems ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == visibleItems.length) {
                          return _buildLoadMore(inventory);
                        }
                        return _buildItemCard(visibleItems[index], inventory);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLoadMore(InventoryProvider inventory) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: IcueButton(
          label: 'Load more items',
          leadingIcon: Icons.expand_more_rounded,
          variant: IcueButtonVariant.outline,
          onPressed: () => inventory.loadItems(more: true),
        ),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item, InventoryProvider inventory) {
    final selectedLines = _lines.where((line) => line.item.id == item.id);
    final isSelected = selectedLines.isNotEmpty;
    final totalSelected = isSelected
        ? selectedLines.fold<double>(0, (sum, line) => sum + line.quantity)
        : null;

    return RequestItemCard(
      item: item,
      storeName: inventory.storeName(item.storeId) ?? '',
      categoryName: inventory.category(item.categoryId)?.name ?? '',
      isSelected: isSelected,
      selectedQuantity: totalSelected,
      onAdd: () => _add(item),
    );
  }
}
