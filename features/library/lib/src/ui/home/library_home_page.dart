import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    final libraryProvider = context.watch<LibraryProvider>();
    final view = libraryProvider.access.can('library.catalogue.view');
    final tiles = <(String, String, String, bool)>[
      (
        'assets/dashboard/library-dashboard.png',
        'Dashboard',
        LibraryRoutes.libraryDashboard,
        view,
      ),
      (
        'assets/dashboard/library-catalogue.png',
        'Catalogue',
        LibraryRoutes.libraryCatalogue,
        view,
      ),
      (
        'assets/dashboard/library-copies.png',
        'Copies',
        LibraryRoutes.libraryCopies,
        libraryProvider.access.can('library.catalogue.manage'),
      ),
      (
        'assets/dashboard/library-categories.png',
        'Categories',
        LibraryRoutes.libraryCategories,
        view,
      ),
      (
        'assets/dashboard/library-libraries.png',
        'Libraries',
        LibraryRoutes.libraryList,
        view,
      ),
      (
        'assets/dashboard/library-circulation.png',
        'Circulation',
        LibraryRoutes.libraryCirculation,
        libraryProvider.access.can('library.circulation.operate'),
      ),
      (
        'assets/dashboard/library-reservations.png',
        'Reservations',
        LibraryRoutes.libraryReservations,
        libraryProvider.access.can('library.circulation.operate'),
      ),
      (
        'assets/dashboard/library-members.png',
        'Members',
        LibraryRoutes.libraryMembers,
        libraryProvider.access.can('library.members.view'),
      ),
      (
        'assets/dashboard/library-policies.png',
        'Borrowing policies',
        LibraryRoutes.libraryPolicies,
        libraryProvider.access.can('library.members.view'),
      ),
      (
        'assets/dashboard/library-fines.png',
        'Fines & Penalties',
        LibraryRoutes.libraryFines,
        libraryProvider.access.can('library.circulation.operate') ||
            libraryProvider.access.can('library.fines.waive'),
      ),
      (
        'assets/dashboard/library-incidents.png',
        'Lost & Damaged',
        LibraryRoutes.libraryIncidents,
        libraryProvider.access.can('library.circulation.operate'),
      ),
      (
        'assets/dashboard/library-transfers.png',
        'Transfers',
        LibraryRoutes.libraryTransfers,
        libraryProvider.access.can('library.catalogue.manage'),
      ),
      (
        'assets/dashboard/library-stock-verification.png',
        'Stock verification',
        LibraryRoutes.libraryVerification,
        libraryProvider.access.can('library.catalogue.manage'),
      ),
      (
        'assets/dashboard/reports.png',
        'Reports',
        LibraryRoutes.libraryReports,
        libraryProvider.access.can('library.reports.view'),
      ),
      (
        'assets/dashboard/library-import.png',
        'Import',
        LibraryRoutes.libraryImport,
        libraryProvider.access.can('library.catalogue.manage') ||
            libraryProvider.access.can('library.circulation.operate'),
      ),
    ];
    final visibleTiles = tiles.where((tile) => tile.$4).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: libraryProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : libraryProvider.errorMessage != null
          ? Center(child: Text(libraryProvider.errorMessage!))
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
