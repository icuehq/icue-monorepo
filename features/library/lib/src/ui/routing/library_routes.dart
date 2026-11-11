/// Route paths and names owned by the library feature.
class LibraryRoutes {
  const LibraryRoutes._();

  static const String library = '/library';
  static const String libraryName = 'library';

  static const String libraryList = '/library/libraries';
  static const String libraryListName = 'library.libraries';

  static const String libraryCategories = '/library/categories';
  static const String libraryCategoriesName = 'library.categories';

  static const String libraryCatalogue = '/library/catalogue';
  static const String libraryCatalogueName = 'library.catalogue';

  static const String libraryBookForm = '/library/catalogue/form';
  static const String libraryBookFormName = 'library.catalogue.form';

  static const String libraryBookDetails = '/library/catalogue/details';
  static const String libraryBookDetailsName = 'library.catalogue.details';

  static const String libraryBookImport = '/library/catalogue/import';
  static const String libraryBookImportName = 'library.catalogue.import';

  static const String libraryMembers = '/library/members';
  static const String libraryMembersName = 'library.members';

  static const String libraryPolicies = '/library/policies';
  static const String libraryPoliciesName = 'library.policies';

  static const String libraryCirculation = '/library/circulation';
  static const String libraryCirculationName = 'library.circulation';
  static const String libraryIssue = '/library/circulation/issue';
  static const String libraryIssueName = 'library.circulation.issue';

  static const String libraryFines = '/library/fines';
  static const String libraryFinesName = 'library.fines';

  static const String libraryIncidents = '/library/incidents';
  static const String libraryIncidentsName = 'library.incidents';
  static const String libraryReports = '/library/reports';
  static const String libraryReportsName = 'library.reports';
}
