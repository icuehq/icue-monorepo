import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key, this.categoryId});

  final String? categoryId;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final inventoryProvider = context.read<InventoryProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (inventoryProvider.categories.isEmpty) {
        await inventoryProvider.loadMasters();
      }
      await inventoryProvider.loadItems(
        search: '',
        categoryId: widget.categoryId,
        clearCategory: widget.categoryId == null,
      );
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        inventoryProvider.loadItems(more: true);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final searching = inventoryProvider.itemSearch.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      floatingActionButton:
          inventoryProvider.access.can('inventory.items.manage')
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.inventoryItemForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Item'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) =>
                  inventoryProvider.loadItems(search: value),
              decoration: InputDecoration(
                hintText: 'Search by whole word in name or code',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          inventoryProvider.loadItems(search: '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String?>(
              isExpanded: true,
              value: inventoryProvider.itemCategoryId,
              items: [
                const DropdownMenuItem(child: Text('All categories')),
                for (final category in inventoryProvider.topCategories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) => inventoryProvider.loadItems(
                categoryId: value,
                clearCategory: value == null,
              ),
            ),
          ),
          Expanded(
            child: inventoryProvider.items.isEmpty
                ? Center(
                    child: inventoryProvider.itemsLoading
                        ? const CircularProgressIndicator()
                        : Text(inventoryProvider.errorMessage ?? 'No items'),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount:
                        inventoryProvider.items.length +
                        (inventoryProvider.hasMoreItems ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == inventoryProvider.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final item = inventoryProvider.items[i];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.code} · ${inventoryProvider.category(item.categoryId)?.name ?? '—'}'
                          ' · ${item.stockUnit}',
                        ),
                        trailing: item.active
                            ? null
                            : const Text(
                                'Inactive',
                                style: TextStyle(color: Colors.grey),
                              ),
                        onTap: () => context.push(
                          '${AppRoutes.inventoryItemDetails}?id=${item.id}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
