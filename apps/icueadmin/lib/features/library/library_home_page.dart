import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/option_grid_card.dart';
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
    final tiles = <(String, String, String, bool)>[
      (
        'assets/dashboard/library-catalogue.png',
        'Catalogue',
        AppRoutes.libraryCatalogue,
        view,
      ),
      (
        'assets/dashboard/library-catalogue.png',
        'Copies',
        AppRoutes.libraryCopies,
        p.access.can('lib.catalogue.manage'),
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
      (
        'assets/dashboard/library.png',
        'Circulation',
        AppRoutes.libraryCirculation,
        p.access.can('lib.circulation.operate'),
      ),
      (
        'assets/dashboard/library.png',
        'Reservations',
        AppRoutes.libraryReservations,
        p.access.can('lib.circulation.operate'),
      ),
      (
        'assets/dashboard/library.png',
        'Members',
        AppRoutes.libraryMembers,
        p.access.can('lib.members.view'),
      ),
      (
        'assets/dashboard/library-categories.png',
        'Borrowing policies',
        AppRoutes.libraryPolicies,
        p.access.can('lib.members.view'),
      ),
    ];
    final visibleTiles = tiles.where((t) => t.$4).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : p.errorMessage != null
          ? Center(child: Text(p.errorMessage!))
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final int crossAxisCount;
                final double iconSize;
                final double spacing;
                final double childAspectRatio;

                if (width >= 900) {
                  crossAxisCount = 4;
                  iconSize = 88.0;
                  spacing = 16.0;
                  childAspectRatio = 1.25;
                } else if (width >= 600) {
                  crossAxisCount = 3;
                  iconSize = 84.0;
                  spacing = 14.0;
                  childAspectRatio = 1.22;
                } else if (width < 360) {
                  crossAxisCount = 2;
                  iconSize = 72.0;
                  spacing = 10.0;
                  childAspectRatio = 1.15;
                } else {
                  crossAxisCount = 2;
                  iconSize = 84.0;
                  spacing = 12.0;
                  childAspectRatio = 1.18;
                }

                return GridView.builder(
                  padding: EdgeInsets.all(spacing + 2),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: visibleTiles.length,
                  itemBuilder: (context, index) {
                    final item = visibleTiles[index];
                    return OptionGridCard(
                      title: item.$2,
                      iconAsset: item.$1,
                      iconSize: iconSize,
                      onTap: () => context.push(item.$3),
                    );
                  },
                );
              },
            ),
    );
  }
}
