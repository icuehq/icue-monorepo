import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/src/ui/routing/library_routes.dart';

/// A Library screen, opened from a [LibraryGroup] tab.
class LibraryEntry {
  const LibraryEntry({required this.label, required this.path});

  final String label;
  final String path;
}

/// One backend sub-action of Library (its tile on phones, its side-nav entry on wide
/// screens); its [tabs] are the screens that sub-action opens.
class LibraryGroup {
  const LibraryGroup({
    required this.label,
    required this.iconAsset,
    required this.tabs,
  });

  final String label;
  final String iconAsset;
  final List<LibraryEntry> tabs;

  String get path => tabs.first.path;
}

/// The Settings group's screens, shown as tabs under each one's app bar.
const librarySettingsTabs = [
  LibraryEntry(label: 'Libraries', path: LibraryRoutes.libraryList),
  LibraryEntry(label: 'Categories', path: LibraryRoutes.libraryCategories),
  LibraryEntry(
    label: 'Borrowing policies',
    path: LibraryRoutes.libraryPolicies,
  ),
];

const _groups = <(String, String, List<LibraryEntry>)>[
  (
    'Issue Books',
    'assets/dashboard/library-circulation.png',
    [
      LibraryEntry(
        label: 'Issued Books',
        path: LibraryRoutes.libraryCirculation,
      ),
    ],
  ),
  (
    'Fines',
    'assets/dashboard/library-fines.png',
    [LibraryEntry(label: 'Fines', path: LibraryRoutes.libraryFines)],
  ),
  (
    'Lost & Damaged',
    'assets/dashboard/library-incidents.png',
    [
      LibraryEntry(
        label: 'Lost & Damaged',
        path: LibraryRoutes.libraryIncidents,
      ),
    ],
  ),
  (
    'Books Catalogue',
    'assets/dashboard/library-catalogue.png',
    [LibraryEntry(label: 'Books', path: LibraryRoutes.libraryCatalogue)],
  ),
  (
    'Members',
    'assets/dashboard/library-members.png',
    [LibraryEntry(label: 'Members', path: LibraryRoutes.libraryMembers)],
  ),
  (
    'Reports',
    'assets/dashboard/reports.png',
    [LibraryEntry(label: 'Reports', path: LibraryRoutes.libraryReports)],
  ),
  ('Settings', 'assets/dashboard/library-libraries.png', librarySettingsTabs),
];

/// The Library groups: the Library tile from Node opens all of them.
final libraryGroups = [
  for (final (label, iconAsset, tabs) in _groups)
    LibraryGroup(label: label, iconAsset: iconAsset, tabs: tabs),
];

/// Side navigation on wide screens: Overview plus the same groups as the phone home grid.
final libraryNavigation = <IcueModuleDestination>[
  const IcueModuleDestination(
    label: 'Overview',
    path: LibraryRoutes.library,
    iconAsset: 'assets/dashboard/library.png',
  ),
  for (final group in libraryGroups)
    IcueModuleDestination(
      label: group.label,
      path: group.path,
      iconAsset: group.iconAsset,
      tabs: [
        for (final tab in group.tabs)
          IcueModuleTab(label: tab.label, path: tab.path),
      ],
    ),
];
