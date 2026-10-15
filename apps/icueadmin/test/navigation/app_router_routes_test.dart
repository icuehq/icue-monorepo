import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/utils/navigation/app_router.dart';

void main() {
  group('AppRouter Route Configuration Tests', () {
    test('contains routes for layout.leaves and layout.homeassignments', () {
      final routes = appRouter.configuration.routes;
      expect(routes.isNotEmpty, isTrue);

      // Search all routes recursively for path matching
      bool hasLeavesRoute = false;
      bool hasHomeAssignmentsRoute = false;

      void checkRoutes(List<RouteBase> dynamicRoutes) {
        for (final route in dynamicRoutes) {
          if (route is GoRoute) {
            if (route.path == 'layout.leaves') {
              hasLeavesRoute = true;
            }
            if (route.path == 'layout.homeassignments') {
              hasHomeAssignmentsRoute = true;
            }
          }
          if (route.routes.isNotEmpty) {
            checkRoutes(route.routes);
          }
        }
      }

      checkRoutes(routes);

      expect(
        hasLeavesRoute,
        isTrue,
        reason: 'appRouter should contain layout.leaves route',
      );
      expect(
        hasHomeAssignmentsRoute,
        isTrue,
        reason: 'appRouter should contain layout.homeassignments route',
      );
    });

    test('contains routes for layout.markscorrectionrequests', () {
      final routes = appRouter.configuration.routes;
      expect(routes.isNotEmpty, isTrue);

      bool hasNestedCorrectionRoute = false;
      bool hasTopLevelCorrectionRoute = false;

      void checkRoutes(
        List<RouteBase> dynamicRoutes, {
        bool underExams = false,
      }) {
        for (final route in dynamicRoutes) {
          if (route is GoRoute) {
            if (route.path == 'layout.markscorrectionrequests') {
              if (underExams) {
                hasNestedCorrectionRoute = true;
              } else {
                hasTopLevelCorrectionRoute = true;
              }
            }
            final isExams = route.path == 'layout.exams';
            if (route.routes.isNotEmpty) {
              checkRoutes(route.routes, underExams: underExams || isExams);
            }
          } else if (route.routes.isNotEmpty) {
            checkRoutes(route.routes, underExams: underExams);
          }
        }
      }

      checkRoutes(routes);

      expect(
        hasNestedCorrectionRoute,
        isTrue,
        reason:
            'appRouter should contain layout.markscorrectionrequests under layout.exams',
      );
      expect(
        hasTopLevelCorrectionRoute,
        isTrue,
        reason:
            'appRouter should contain layout.markscorrectionrequests as standalone route',
      );
    });
  });
}
