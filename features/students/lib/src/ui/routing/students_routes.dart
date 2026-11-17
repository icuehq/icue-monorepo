/// Route paths owned by the students feature. Paths match the old parent app
/// because push payloads and menu actions send them.
class StudentsRoutes {
  const StudentsRoutes._();

  static const String studentsList = '/students-list';

  /// Child of the app's `/profile` route.
  static const String children = 'children';
  static const String childrenPath = '/profile/children';
}
