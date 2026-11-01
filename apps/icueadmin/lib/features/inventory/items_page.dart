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
    final p = context.read<InventoryProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (p.categories.isEmpty) await p.loadMasters();
      await p.loadItems(
        search: '',
        categoryId: widget.categoryId,
        clearCategory: widget.categoryId == null,
      );
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) p.loadItems(more: true);
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
    final p = context.watch<InventoryProvider>();
    final searching = p.itemSearch.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      floatingActionButton: p.access.can('inv.items.manage')
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
              onSubmitted: (v) => p.loadItems(search: v),
              decoration: InputDecoration(
                hintText: 'Search by whole word in name or code',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          p.loadItems(search: '');
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
              value: p.itemCategoryId,
              items: [
                const DropdownMenuItem(child: Text('All categories')),
                for (final c in p.topCategories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) =>
                  p.loadItems(categoryId: v, clearCategory: v == null),
            ),
          ),
          Expanded(
            child: p.items.isEmpty
                ? Center(
                    child: p.itemsLoading
                        ? const CircularProgressIndicator()
                        : Text(p.errorMessage ?? 'No items'),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: p.items.length + (p.hasMoreItems ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == p.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final item = p.items[i];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.code} · ${p.category(item.categoryId)?.name ?? '—'}'
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
