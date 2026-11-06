import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/libraries/widgets/library_category_sheet.dart';

class LibraryCategoriesPage extends StatelessWidget {
  const LibraryCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final canEdit = libraryProvider.access.can('library.catalogue');
    final rows = <(LibraryCategory, bool)>[
      for (final category in libraryProvider.topCategories) ...[
        (category, false),
        for (final category in libraryProvider.categories.where(
          (category) => category.parentId == category.id,
        ))
          (category, true),
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Book categories')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => LibraryCategorySheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Category'),
            )
          : null,
      body: rows.isEmpty
          ? Center(
              child: libraryProvider.isLoading
                  ? const CircularProgressIndicator()
                  : SeedDefaultsButton<LibraryProvider>(
                      label: 'Add default categories',
                      canSeed: (provider) =>
                          provider.access.can('library.catalogue'),
                      seed: (provider) => provider.seedDefaults(),
                    ),
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
                      onSelected: (value) => _onMenu(context, value, c),
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

  Future<void> _onMenu(
    BuildContext context,
    String value,
    LibraryCategory category,
  ) async {
    final libraryProvider = context.read<LibraryProvider>();
    switch (value) {
      case 'books':
        await context.push(
          '${LibraryRoutes.libraryCatalogue}?category=${category.id}',
        );
      case 'edit':
        await LibraryCategorySheet.show(context, category: category);
      case 'sub':
        await LibraryCategorySheet.show(context, parentId: category.id);
      case 'toggle':
        if (!await libraryProvider.setCategoryActive(
              category.id,
              active: !category.active,
            ) &&
            context.mounted) {
          showMessage(context, libraryProvider.errorMessage ?? 'Failed');
        }
    }
  }
}
