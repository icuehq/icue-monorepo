import 'package:go_router/go_router.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/book_details_page.dart';
import 'package:school_library/src/ui/catalogue/book_form_page.dart';
import 'package:school_library/src/ui/catalogue/catalogue_page.dart';
import 'package:school_library/src/ui/catalogue/copies_page.dart';
import 'package:school_library/src/ui/circulation/circulation_page.dart';
import 'package:school_library/src/ui/fines/fines_page.dart';
import 'package:school_library/src/ui/home/library_home_page.dart';
import 'package:school_library/src/ui/incidents/incidents_page.dart';
import 'package:school_library/src/ui/insights/dashboard/library_dashboard_page.dart';
import 'package:school_library/src/ui/insights/import/library_import_page.dart';
import 'package:school_library/src/ui/insights/reports/library_report_page.dart';
import 'package:school_library/src/ui/insights/reports/library_reports_page.dart';
import 'package:school_library/src/ui/libraries/libraries_page.dart';
import 'package:school_library/src/ui/libraries/library_categories_page.dart';
import 'package:school_library/src/ui/members/members_page.dart';
import 'package:school_library/src/ui/policies/policies_page.dart';
import 'package:school_library/src/ui/reservations/reservations_page.dart';
import 'package:school_library/src/ui/transfers/transfer_form_page.dart';
import 'package:school_library/src/ui/transfers/transfer_page.dart';
import 'package:school_library/src/ui/transfers/transfers_page.dart';
import 'package:school_library/src/ui/verification/verification_page.dart';

/// Library screens as go_router routes; mount inside the app's shell.
List<RouteBase> libraryRoutes() => [
  GoRoute(
    path: LibraryRoutes.library,
    name: LibraryRoutes.libraryName,
    builder: (context, state) => const LibraryHomePage(),
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
    path: LibraryRoutes.libraryCopies,
    name: LibraryRoutes.libraryCopiesName,
    builder: (context, state) => const CopiesPage(),
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
    path: LibraryRoutes.libraryTransfers,
    name: LibraryRoutes.libraryTransfersName,
    builder: (context, state) => const LibraryTransfersPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryTransferForm,
    name: LibraryRoutes.libraryTransferFormName,
    builder: (context, state) => const LibraryTransferFormPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryTransferDetail,
    name: LibraryRoutes.libraryTransferDetailName,
    builder: (context, state) =>
        LibraryTransferPage(transferId: state.uri.queryParameters['id'] ?? ''),
  ),
  GoRoute(
    path: LibraryRoutes.libraryVerification,
    name: LibraryRoutes.libraryVerificationName,
    builder: (context, state) => const LibraryVerificationPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryDashboard,
    name: LibraryRoutes.libraryDashboardName,
    builder: (context, state) => const LibraryDashboardPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryReports,
    name: LibraryRoutes.libraryReportsName,
    builder: (context, state) => const LibraryReportsPage(),
  ),
  GoRoute(
    path: LibraryRoutes.libraryReport,
    name: LibraryRoutes.libraryReportName,
    builder: (context, state) =>
        LibraryReportPage(def: state.extra! as LibraryReportDef),
  ),
  GoRoute(
    path: LibraryRoutes.libraryImport,
    name: LibraryRoutes.libraryImportName,
    builder: (context, state) => const LibraryImportPage(),
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
