import 'package:admin_ui/admin_ui.dart';
import 'package:icue_firebase/icue_firebase.dart';
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

/// The Catalogue group's screens, shown as tabs under each one's app bar.
const libraryCatalogueTabs = [
  LibraryEntry(label: 'Books', path: LibraryRoutes.libraryCatalogue),
  LibraryEntry(label: 'Copies', path: LibraryRoutes.libraryCopies),
  LibraryEntry(
    label: 'Stock verification',
    path: LibraryRoutes.libraryVerification,
  ),
];

/// The Members group's screens, shown as tabs under each one's app bar.
const libraryMemberTabs = [
  LibraryEntry(label: 'Members', path: LibraryRoutes.libraryMembers),
  LibraryEntry(
    label: 'Borrowing policies',
    path: LibraryRoutes.libraryPolicies,
  ),
];

/// The Settings group's screens, shown as tabs under each one's app bar.
const librarySettingsTabs = [
  LibraryEntry(label: 'Libraries', path: LibraryRoutes.libraryList),
  LibraryEntry(label: 'Categories', path: LibraryRoutes.libraryCategories),
];

final _groups =
    <(String, String, List<(LibraryEntry, bool Function(ModuleAccess))>)>[
      (
        'Circulation',
        'assets/dashboard/library-circulation.png',
        [
          (
            const LibraryEntry(
              label: 'Loans',
              path: LibraryRoutes.libraryCirculation,
            ),
            _circulation,
          ),
          (
            const LibraryEntry(
              label: 'Reservations',
              path: LibraryRoutes.libraryReservations,
            ),
            _circulation,
          ),
          (
            const LibraryEntry(
              label: 'Fines',
              path: LibraryRoutes.libraryFines,
            ),
            _fines,
          ),
          (
            const LibraryEntry(
              label: 'Lost & Damaged',
              path: LibraryRoutes.libraryIncidents,
            ),
            _circulation,
          ),
        ],
      ),
      (
        'Catalogue',
        'assets/dashboard/library-catalogue.png',
        [for (final tab in libraryCatalogueTabs) (tab, _catalogue)],
      ),
      (
        'Members',
        'assets/dashboard/library-members.png',
        [for (final tab in libraryMemberTabs) (tab, _members)],
      ),
      (
        'Reports',
        'assets/dashboard/reports.png',
        [
          (
            const LibraryEntry(
              label: 'Reports',
              path: LibraryRoutes.libraryReports,
            ),
            _reports,
          ),
        ],
      ),
      (
        'Settings',
        'assets/dashboard/library-libraries.png',
        [for (final tab in librarySettingsTabs) (tab, _catalogue)],
      ),
    ];

bool _catalogue(ModuleAccess access) => access.can('library.catalogue');
bool _circulation(ModuleAccess access) =>
    access.can('library.circulation.operate');
bool _fines(ModuleAccess access) =>
    access.can('library.circulation.operate') ||
    access.can('library.fines.waive');
bool _members(ModuleAccess access) => access.can('library.members.view');
bool _reports(ModuleAccess access) => access.can('library.reports.view');

/// The Library groups [access] may open, each with only the screens it opens.
List<LibraryGroup> libraryGroups(ModuleAccess access) => [
  for (final (label, iconAsset, screens) in _groups)
    if ([
          for (final (entry, allowed) in screens)
            if (allowed(access)) entry,
        ]
        case final tabs when tabs.isNotEmpty)
      LibraryGroup(label: label, iconAsset: iconAsset, tabs: tabs),
];

/// Side navigation on wide screens: Overview plus the same groups as the phone home grid.
List<ModuleDestination> libraryNavigation(ModuleAccess access) => [
  const ModuleDestination(
    label: 'Overview',
    path: LibraryRoutes.library,
    iconAsset: 'assets/dashboard/library.png',
  ),
  for (final group in libraryGroups(access))
    ModuleDestination(
      label: group.label,
      path: group.path,
      iconAsset: group.iconAsset,
      tabs: [
        for (final tab in group.tabs)
          ModuleTab(label: tab.label, path: tab.path),
      ],
    ),
];
