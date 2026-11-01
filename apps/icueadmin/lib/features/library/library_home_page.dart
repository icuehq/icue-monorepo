import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class LibraryHomePage extends StatefulWidget {
  const LibraryHomePage({super.key});

  @override
  State<LibraryHomePage> createState() => _LibraryHomePageState();
}

class _LibraryHomePageState extends State<LibraryHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadMasters(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final view = p.access.can('lib.catalogue.view');
    final tiles = <(IconData, String, String, bool)>[
      (Icons.menu_book_rounded, 'Catalogue', AppRoutes.libraryCatalogue, view),
      (Icons.category_rounded, 'Categories', AppRoutes.libraryCategories, view),
      (Icons.local_library_rounded, 'Libraries', AppRoutes.libraryList, view),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : p.errorMessage != null
          ? Center(child: Text(p.errorMessage!))
          : GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final t in tiles.where((t) => t.$4))
                  Card(
                    child: InkWell(
                      onTap: () => context.push(t.$3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(t.$1, size: 36),
                          const SizedBox(height: 8),
                          Text(t.$2),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
