import 'package:go_router/go_router.dart';
import 'package:students/src/ui/children_page.dart';
import 'package:students/src/ui/routing/students_routes.dart';
import 'package:students/src/ui/students_list_page.dart';

/// Top-level routes; mount in the app router.
List<RouteBase> studentsRoutes() => [
  GoRoute(
    name: 'students-list-page',
    path: StudentsRoutes.studentsList,
    builder: (_, state) =>
        StudentsListPage(isSwitching: (state.extra as bool?) ?? false),
  ),
];

/// Routes nested under the app's `/profile` route.
List<RouteBase> studentsProfileRoutes() => [
  GoRoute(
    name: 'children-page',
    path: StudentsRoutes.children,
    builder: (_, _) => const ChildrenPage(),
  ),
];
