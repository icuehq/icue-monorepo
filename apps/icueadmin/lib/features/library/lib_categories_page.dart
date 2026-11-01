import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/lib_category_sheet.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class LibCategoriesPage extends StatelessWidget {
  const LibCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final canEdit = p.access.can('lib.catalogue.manage');
    final rows = <(LibCategory, bool)>[
      for (final c in p.topCategories) ...[
        (c, false),
        for (final s in p.categories.where((s) => s.parentId == c.id))
          (s, true),
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Book categories')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => LibCategorySheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Category'),
            )
          : null,
      body: rows.isEmpty
          ? Center(
              child: p.isLoading
                  ? const CircularProgressIndicator()
                  : const SeedCategoriesButton(),
            )
          : ListView(
              children: [
                for (final (c, isSub) in rows)
                  ListTile(
                    contentPadding: EdgeInsets.only(
                      left: isSub ? 40 : 16,
                      right: 8,
                    ),
                    title: Text(c.name),
                    subtitle: Text(c.code),
                    leading: c.active ? null : const InactiveBadge(),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) => _onMenu(context, v, c),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'books',
                          child: Text('View books'),
                        ),
                        if (canEdit) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          if (!isSub)
                            const PopupMenuItem(
                              value: 'sub',
                              child: Text('Add subcategory'),
                            ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(c.active ? 'Deactivate' : 'Activate'),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _onMenu(BuildContext context, String v, LibCategory c) async {
    final p = context.read<LibraryProvider>();
    switch (v) {
      case 'books':
        await context.push('${AppRoutes.libraryCatalogue}?category=${c.id}');
      case 'edit':
        await LibCategorySheet.show(context, category: c);
      case 'sub':
        await LibCategorySheet.show(context, parentId: c.id);
      case 'toggle':
        if (!await p.setCategoryActive(c.id, active: !c.active) &&
            context.mounted) {
          invSnack(context, p.errorMessage ?? 'Failed');
        }
    }
  }
}
