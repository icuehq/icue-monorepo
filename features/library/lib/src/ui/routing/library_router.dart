import 'package:admin_ui/admin_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/book_details_page.dart';
import 'package:school_library/src/ui/catalogue/book_form_page.dart';
import 'package:school_library/src/ui/catalogue/catalogue_page.dart';
import 'package:school_library/src/ui/circulation/circulation_page.dart';
import 'package:school_library/src/ui/circulation/issue_books_page.dart';
import 'package:school_library/src/ui/circulation/widgets/scan_listener.dart';
import 'package:school_library/src/ui/fines/fines_page.dart';
import 'package:school_library/src/ui/incidents/incidents_page.dart';
import 'package:school_library/src/ui/insights/overview/library_overview_page.dart';
import 'package:school_library/src/ui/insights/reports/library_reports_page.dart';
import 'package:school_library/src/ui/libraries/libraries_page.dart';
import 'package:school_library/src/ui/libraries/library_categories_page.dart';
import 'package:school_library/src/ui/members/members_page.dart';
import 'package:school_library/src/ui/policies/policies_page.dart';
import 'package:school_library/src/ui/reservations/reservations_page.dart';
import 'package:school_library/src/ui/routing/library_destinations.dart';

/// Library screens as go_router routes, inside a shell that adds side navigation on wide screens.
List<RouteBase> libraryRoutes() => [
  ShellRoute(
    builder: (context, state, child) {
      final shell = ModuleShell(
        title: 'Library',
        homePath: LibraryRoutes.library,
        location: state.uri.path,
        destinations: libraryNavigation,
        child: child,
      );
      return LibraryScanListener(child: shell);
    },
    routes: _libraryPages,
  ),
];

final _libraryPages = <RouteBase>[
  GoRoute(
    path: LibraryRoutes.library,
    name: LibraryRoutes.libraryName,
    builder: (context, state) => const LibraryLanding(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryList,
    name: LibraryRoutes.libraryListName,
    builder: (context, state) => const LibrariesPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryCategories,
    name: LibraryRoutes.libraryCategoriesName,
    builder: (context, state) => const LibraryCategoriesPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryCatalogue,
    name: LibraryRoutes.libraryCatalogueName,
    builder: (context, state) =>
        CataloguePage(categoryId: state.uri.queryParameters['category']),
  ),
  GoRoute(
    path: LibraryRoutes.libraryBookForm,
    name: LibraryRoutes.libraryBookFormName,
    builder: (context, state) =>
        BookFormPage(book: state.extra as LibraryBook?),
  ),
  GoRoute(
    path: LibraryRoutes.libraryMembers,
    name: LibraryRoutes.libraryMembersName,
    builder: (context, state) => const MembersPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryCirculation,
    name: LibraryRoutes.libraryCirculationName,
    builder: (context, state) => const CirculationPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryIssue,
    name: LibraryRoutes.libraryIssueName,
    builder: (context, state) =>
        IssueBooksPage(copy: state.extra as LibraryCopy?),
  ),
  GoRoute(
    path: LibraryRoutes.libraryReservations,
    name: LibraryRoutes.libraryReservationsName,
    builder: (context, state) => const ReservationsPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryFines,
    name: LibraryRoutes.libraryFinesName,
    builder: (context, state) => const FinesPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryIncidents,
    name: LibraryRoutes.libraryIncidentsName,
    builder: (context, state) => const IncidentsPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryReports,
    name: LibraryRoutes.libraryReportsName,
    builder: (context, state) => const LibraryReportsPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryPolicies,
    name: LibraryRoutes.libraryPoliciesName,
    builder: (context, state) => const PoliciesPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryBookDetails,
    name: LibraryRoutes.libraryBookDetailsName,
    builder: (context, state) =>
        BookDetailsPage(bookId: state.uri.queryParameters['id'] ?? ''),
  ),
];
