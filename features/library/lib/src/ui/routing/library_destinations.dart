import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/src/ui/routing/library_routes.dart';

/// A Library screen reachable from the home grid; [libraryNavigation] groups them for wide screens.
class LibraryEntry {
  const LibraryEntry({
    required this.label,
    required this.path,
    required this.iconAsset,
  });

  final String label;
  final String path;
  final String iconAsset;
}

const _entries = <(LibraryEntry, bool Function(ModuleAccess access))>[
  (
    LibraryEntry(
      label: 'Circulation',
      path: LibraryRoutes.libraryCirculation,
      iconAsset: 'assets/dashboard/library-circulation.png',
    ),
    _circulation,
  ),
  (
    LibraryEntry(
      label: 'Reservations',
      path: LibraryRoutes.libraryReservations,
      iconAsset: 'assets/dashboard/library-reservations.png',
    ),
    _circulation,
  ),
  (
    LibraryEntry(
      label: 'Fines & Penalties',
      path: LibraryRoutes.libraryFines,
      iconAsset: 'assets/dashboard/library-fines.png',
    ),
    _fines,
  ),
  (
    LibraryEntry(
      label: 'Lost & Damaged',
      path: LibraryRoutes.libraryIncidents,
      iconAsset: 'assets/dashboard/library-incidents.png',
    ),
    _circulation,
  ),
  (
    LibraryEntry(
      label: 'Catalogue',
      path: LibraryRoutes.libraryCatalogue,
      iconAsset: 'assets/dashboard/library-catalogue.png',
    ),
    _catalogue,
  ),
  (
    LibraryEntry(
      label: 'Copies',
      path: LibraryRoutes.libraryCopies,
      iconAsset: 'assets/dashboard/library-copies.png',
    ),
    _catalogue,
  ),
  (
    LibraryEntry(
      label: 'Members',
      path: LibraryRoutes.libraryMembers,
      iconAsset: 'assets/dashboard/library-members.png',
    ),
    _members,
  ),
  (
    LibraryEntry(
      label: 'Transfers',
      path: LibraryRoutes.libraryTransfers,
      iconAsset: 'assets/dashboard/library-transfers.png',
    ),
    _catalogue,
  ),
  (
    LibraryEntry(
      label: 'Stock verification',
      path: LibraryRoutes.libraryVerification,
      iconAsset: 'assets/dashboard/library-stock-verification.png',
    ),
    _catalogue,
  ),
  (
    LibraryEntry(
      label: 'Import',
      path: LibraryRoutes.libraryImport,
      iconAsset: 'assets/dashboard/library-import.png',
    ),
    _import,
  ),
  (
    LibraryEntry(
      label: 'Dashboard',
      path: LibraryRoutes.libraryDashboard,
      iconAsset: 'assets/dashboard/library-dashboard.png',
    ),
    _catalogue,
  ),
  (
    LibraryEntry(
      label: 'Libraries',
      path: LibraryRoutes.libraryList,
      iconAsset: 'assets/dashboard/library-libraries.png',
    ),
    _catalogue,
  ),
  (
    LibraryEntry(
      label: 'Categories',
      path: LibraryRoutes.libraryCategories,
      iconAsset: 'assets/dashboard/library-categories.png',
    ),
    _catalogue,
  ),
  (
    LibraryEntry(
      label: 'Borrowing policies',
      path: LibraryRoutes.libraryPolicies,
      iconAsset: 'assets/dashboard/library-policies.png',
    ),
    _members,
  ),
  (
    LibraryEntry(
      label: 'Reports',
      path: LibraryRoutes.libraryReports,
      iconAsset: 'assets/dashboard/reports.png',
    ),
    _reports,
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
bool _import(ModuleAccess access) =>
    access.can('library.catalogue') ||
    access.can('library.circulation.operate');

/// The Library screens [access] may open, in navigation order.
List<LibraryEntry> libraryEntries(ModuleAccess access) => [
  for (final (entry, allowed) in _entries)
    if (allowed(access)) entry,
];

/// Side navigation on wide screens: seven entries, several with tabs.
///
/// An entry or tab appears only when [access] opens its screen.
List<ModuleDestination> libraryNavigation(ModuleAccess access) {
  final open = {for (final entry in libraryEntries(access)) entry.path};
  const groups = <(String, IconData, List<(String, String)>)>[
    (
      'Circulation',
      Icons.swap_horiz_rounded,
      [
        ('Loans', LibraryRoutes.libraryCirculation),
        ('Reservations', LibraryRoutes.libraryReservations),
        ('Fines', LibraryRoutes.libraryFines),
        ('Lost & damaged', LibraryRoutes.libraryIncidents),
      ],
    ),
    (
      'Catalogue',
      Icons.menu_book_outlined,
      [
        ('Books', LibraryRoutes.libraryCatalogue),
        ('Copies & acquisitions', LibraryRoutes.libraryCopies),
      ],
    ),
    (
      'Members',
      Icons.people_outline_rounded,
      [('Members', LibraryRoutes.libraryMembers)],
    ),
    (
      'Stock control',
      Icons.inventory_2_outlined,
      [
        ('Transfers', LibraryRoutes.libraryTransfers),
        ('Stock verification', LibraryRoutes.libraryVerification),
      ],
    ),
    (
      'Reports',
      Icons.assessment_outlined,
      [('Reports', LibraryRoutes.libraryReports)],
    ),
    (
      'Settings',
      Icons.settings_outlined,
      [
        ('Libraries', LibraryRoutes.libraryList),
        ('Borrowing policies', LibraryRoutes.libraryPolicies),
        ('Categories', LibraryRoutes.libraryCategories),
        ('Import', LibraryRoutes.libraryImport),
      ],
    ),
  ];
  return [
    const ModuleDestination(
      label: 'Overview',
      path: LibraryRoutes.library,
      icon: Icons.space_dashboard_outlined,
    ),
    for (final (label, icon, tabs) in groups)
      if (tabs.any((tab) => open.contains(tab.$2)))
        ModuleDestination(
          label: label,
          path: tabs.firstWhere((tab) => open.contains(tab.$2)).$2,
          icon: icon,
          tabs: [
            for (final (tabLabel, path) in tabs)
              if (open.contains(path)) ModuleTab(label: tabLabel, path: path),
          ],
        ),
  ];
}
