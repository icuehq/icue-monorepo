import 'package:auth/auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/scan_listener.dart';
import 'package:school_library/src/ui/routing/library_destinations.dart';
import 'package:school_library/src/ui/routing/library_pages.dart'
    deferred as pages;
import 'package:school_library/src/ui/widgets/librarian_logout_button.dart';
import 'package:school_library/src/ui/widgets/no_library_assigned_gate.dart';

Widget _libraryPage(WidgetBuilder builder) =>
    IcueDeferred(load: pages.loadLibrary, builder: builder);

/// Library screens as go_router routes, inside a shell that adds side navigation on wide screens.
List<RouteBase> libraryRoutes() => [
  ShellRoute(
    builder: (context, state, child) {
      final shell = IcueModuleShell(
        title: 'Library',
        homePath: LibraryRoutes.library,
        // Librarians live in this module; there is no dashboard to go back to.
        exitPath: context.read<AuthProvider>().isLibrarian ? null : '/',
        location: state.uri.path,
        footer: const LibrarianLogoutButton(expanded: true),
        destinations: libraryNavigation,
        child: child,
      );
      return NoLibraryAssignedGate(child: LibraryScanListener(child: shell));
    },
    routes: _libraryPages,
  ),
];

final _libraryPages = <RouteBase>[
  GoRoute(
    path: LibraryRoutes.library,
    name: LibraryRoutes.libraryName,
    builder: (context, state) => _libraryPage((_) => pages.LibraryLanding()),
  ),
  GoRoute(
    path: LibraryRoutes.libraryList,
    name: LibraryRoutes.libraryListName,
    builder: (context, state) => _libraryPage((_) => pages.LibrariesPage()),
  ),
  GoRoute(
    path: LibraryRoutes.libraryCategories,
    name: LibraryRoutes.libraryCategoriesName,
    builder: (context, state) =>
        _libraryPage((_) => pages.LibraryCategoriesPage()),
  ),
  GoRoute(
    path: LibraryRoutes.libraryCatalogue,
    name: LibraryRoutes.libraryCatalogueName,
    builder: (context, state) => _libraryPage(
      (_) => pages.CataloguePage(
        categoryId: state.uri.queryParameters['category'],
      ),
    ),
  ),
  GoRoute(
    path: LibraryRoutes.libraryBookForm,
    name: LibraryRoutes.libraryBookFormName,
    builder: (context, state) => _libraryPage(
      (_) => pages.BookFormPage(book: state.extra as LibraryBook?),
    ),
  ),
  GoRoute(
    path: LibraryRoutes.libraryBookImport,
    name: LibraryRoutes.libraryBookImportName,
    builder: (context, state) => _libraryPage((_) => pages.BookImportPage()),
  ),
  GoRoute(
    path: LibraryRoutes.libraryMembers,
    name: LibraryRoutes.libraryMembersName,
    builder: (context, state) => _libraryPage((_) => pages.MembersPage()),
  ),
  GoRoute(
    path: LibraryRoutes.libraryCirculation,
    name: LibraryRoutes.libraryCirculationName,
    builder: (context, state) => _libraryPage((_) => pages.CirculationPage()),
  ),
  GoRoute(
    path: LibraryRoutes.libraryIssue,
    name: LibraryRoutes.libraryIssueName,
    builder: (context, state) => _libraryPage(
      (_) => pages.IssueBooksPage(copy: state.extra as LibraryCopy?),
    ),
  ),
  GoRoute(
    path: LibraryRoutes.libraryFines,
    name: LibraryRoutes.libraryFinesName,
    builder: (context, state) => _libraryPage((_) => pages.FinesPage()),
  ),
  GoRoute(
    path: LibraryRoutes.libraryIncidents,
    name: LibraryRoutes.libraryIncidentsName,
    builder: (context, state) => _libraryPage((_) => pages.IncidentsPage()),
  ),
  GoRoute(
    path: LibraryRoutes.libraryReports,
    name: LibraryRoutes.libraryReportsName,
    builder: (context, state) =>
        _libraryPage((_) => pages.LibraryReportsPage()),
  ),
  GoRoute(
    path: LibraryRoutes.libraryPolicies,
    name: LibraryRoutes.libraryPoliciesName,
    builder: (context, state) => _libraryPage((_) => pages.PoliciesPage()),
  ),
  GoRoute(
    path: LibraryRoutes.libraryBookDetails,
    name: LibraryRoutes.libraryBookDetailsName,
    builder: (context, state) => _libraryPage(
      (_) =>
          pages.BookDetailsPage(bookId: state.uri.queryParameters['id'] ?? ''),
    ),
  ),
];
