import 'package:announcements/announcements.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:gatepass/gatepass.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:impl/features/dashboard/dashboard_page.dart';
import 'package:impl/features/menu/link_web_view_page.dart';
import 'package:impl/features/menu/sub_menu_page.dart';
import 'package:impl/features/profile/privacy_policy_page.dart';
import 'package:impl/features/profile/profile_page.dart';
import 'package:impl/features/profile/terms_and_conditions_page.dart';
import 'package:impl/routing/app_navigator.dart';
import 'package:impl/routing/app_routes.dart';
import 'package:impl/widgets/coming_soon_page.dart';
import 'package:mess_meals/mess_meals.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:parent_transport/parent_transport.dart';
import 'package:safehands/safehands.dart';
import 'package:school_connect/school_connect.dart';
import 'package:students/students.dart';

GoRouter createRouter({
  required ParentAuthProvider auth,
  required ValueNotifier<Locale> locale,
}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  // Named routes become screen_view events; names match the old app's.
  observers: [AnalyticsService.instance.observer],
  initialLocation: AppRoutes.dashboard,
  refreshListenable: auth,
  // Unknown paths, e.g. a menu action this app does not have yet.
  errorBuilder: (_, _) => const ComingSoonPage(),
  redirect: (context, state) {
    final path = state.matchedLocation;
    final onLogin =
        path == ParentAuthRoutes.login || path == ParentAuthRoutes.otp;
    if (!auth.isSignedIn) return onLogin ? null : ParentAuthRoutes.login;
    if (onLogin) return StudentsRoutes.studentsList;
    if (auth.selectedStudent == null && path != StudentsRoutes.studentsList) {
      return StudentsRoutes.studentsList;
    }
    return null;
  },
  routes: [
    ...parentAuthRoutes(),
    GoRoute(
      name: 'coming-soon-page',
      path: '/coming-soon',
      builder: (_, _) => const ComingSoonPage(),
    ),
    ...studentsRoutes(),
    GoRoute(
      name: 'dashboard-page',
      path: AppRoutes.dashboard,
      builder: (_, _) => const DashboardPage(),
      routes: [
        ...parentAnnouncementsRoutes(),
        ...parentGatePassRoutes(),
        ...parentTransportRoutes(),
        ...safeHandsRoutes(),
        ...complaintRoutes(),
        GoRoute(
          name: 'school-connect-page',
          path: SchoolConnectRoutes.hub,
          builder: (context, _) => SubMenuPage(
            routeState: SchoolConnectRoutes.hub,
            title: ParentLocalizations.of(context).schoolConnect,
          ),
          routes: [
            ...schoolConnectHubRoutes(),
            _link(
              AppRoutes.appointments,
              'appointments-page',
              'APPNTS',
              (l) => l.appointments,
            ),
            ..._comingSoon(['layout.conntect', 'layout.parentteachermeeting']),
          ],
        ),
        GoRoute(
          name: 'academics-page',
          path: AppRoutes.academics,
          builder: (context, _) => SubMenuPage(
            routeState: AppRoutes.academics,
            title: ParentLocalizations.of(context).academics,
          ),
          routes: _comingSoon([
            'layout.testexams',
            'layout.marksgrades',
            'layout.observationsrecommendes',
            'layout.ptmdiscussions',
          ]),
        ),
        GoRoute(
          name: 'mess-meals-page',
          path: MessMealsRoutes.hub,
          builder: (context, _) => SubMenuPage(
            routeState: MessMealsRoutes.hub,
            title: ParentLocalizations.of(context).messMeals,
            iconAssetFor: (item) => item.displayName == 'Meal Menu'
                ? 'packages/mess_meals/assets/menu.svg'
                : 'packages/mess_meals/assets/meal-purchase.svg',
          ),
          routes: messMealsHubRoutes(),
        ),
        _link(AppRoutes.payments, 'payment-page', 'FEES', (l) => l.payments),
        ..._comingSoon(['layout.homeworks']),
        GoRoute(
          name: 'profile-page',
          path: 'profile',
          builder: (_, _) => ProfilePage(locale: locale),
          routes: [
            ...studentsProfileRoutes(),
            ...parentTransportProfileRoutes(),
            GoRoute(
              name: 'terms-and-conditions-page',
              path: AppRoutes.termsAndConditions,
              builder: (_, _) => const TermsAndConditionsPage(),
            ),
            GoRoute(
              name: 'privacy-policy-page',
              path: AppRoutes.privacyPolicy,
              builder: (_, _) => const PrivacyPolicyPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// A page that opens a school web address chosen by the server per student.
GoRoute _link(
  String path,
  String name,
  String linkType,
  String Function(ParentLocalizations) title,
) => GoRoute(
  name: name,
  path: path,
  builder: (context, _) => LinkWebViewPage(
    linkType: linkType,
    title: title(ParentLocalizations.of(context)),
  ),
);

/// Menu entries the app lists but has no screen for yet; they keep their
/// place in the back stack instead of falling to the unknown-route page.
List<GoRoute> _comingSoon(List<String> paths) => [
  for (final path in paths)
    GoRoute(path: path, builder: (_, _) => const ComingSoonPage()),
];
