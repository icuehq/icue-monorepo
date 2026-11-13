import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/routing/library_destinations.dart';
import 'package:school_library/src/ui/widgets/librarian_logout_button.dart';

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
    final visibleTiles = libraryGroups;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: const [LibrarianLogoutButton()],
      ),
      body: libraryProvider.isLoading
          ? const IcueSkeletonTileGrid()
          : libraryProvider.errorMessage != null
          ? IcueEmptyState.error(
              message: libraryProvider.errorMessage,
              onAction: libraryProvider.loadMasters,
            )
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
                    return IcueOptionGridCard(
                      title: item.label,
                      iconAsset: item.iconAsset,
                      iconSize: iconSize,
                      onTap: () => context.push(item.path),
                    );
                  },
                );
              },
            ),
    );
  }
}
