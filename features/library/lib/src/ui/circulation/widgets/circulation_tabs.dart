import 'package:school_library/src/ui/routing/library_destinations.dart';
import 'package:school_library/src/ui/routing/library_routes.dart';
import 'package:school_library/src/ui/routing/library_tab_bar.dart';

enum CirculationTab {
  loans('Loans', LibraryRoutes.libraryCirculation),
  fines('Fines', LibraryRoutes.libraryFines),
  incidents('Lost & damaged', LibraryRoutes.libraryIncidents);

  const CirculationTab(this.label, this.path);

  final String label;
  final String path;
}

/// Persistent tabs inside the circulation app bar across loans, fines, and incidents.
class CirculationTabBar extends LibraryTabBar {
  CirculationTabBar({required CirculationTab activeTab, super.key})
    : super(
        tabs: [
          for (final tab in CirculationTab.values)
            LibraryEntry(label: tab.label, path: tab.path),
        ],
        activePath: activeTab.path,
      );
}
