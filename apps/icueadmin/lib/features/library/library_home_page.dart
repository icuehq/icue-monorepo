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
    final color = Theme.of(context).primaryColorDark;
    final tiles = <(String, String, String, bool)>[
      (
        'assets/dashboard/library-catalogue.png',
        'Catalogue',
        AppRoutes.libraryCatalogue,
        view,
      ),
      (
        'assets/dashboard/library-categories.png',
        'Categories',
        AppRoutes.libraryCategories,
        view,
      ),
      (
        'assets/dashboard/library-libraries.png',
        'Libraries',
        AppRoutes.libraryList,
        view,
      ),
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
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.3,
              children: [
                for (final t in tiles.where((t) => t.$4))
                  Card(
                    elevation: 1,
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () => context.push(t.$3),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(t.$1, width: 56, height: 56),
                            const SizedBox(height: 12),
                            Text(
                              t.$2,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
