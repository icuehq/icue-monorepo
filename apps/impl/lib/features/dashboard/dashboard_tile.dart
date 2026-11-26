import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:students/students.dart';

/// Server menu names that have a translation; others show the server text.
final Map<String, String Function(ParentLocalizations)> _names = {
  'Track Bus': (l) => l.trackBus,
  'Safe Hands': (l) => l.safeHands,
  'School Connect': (l) => l.schoolConnect,
  'Home Works': (l) => l.homeWork,
  'Academics': (l) => l.academics,
  'Announcements': (l) => l.announcements,
  'Payments': (l) => l.payments,
  'Mess & Meals': (l) => l.messMeals,
  'Meal Menu': (l) => l.mealMenu,
  'Instant Meal Purchase': (l) => l.instantMealPurchase,
  'Test & Exams': (l) => l.testAndExams,
  'Marks & Grades': (l) => l.marksAndGrades,
  'Observations & Recommendes': (l) => l.observationsAndRecommendations,
  'P T M Discussions': (l) => l.ptmDiscussions,
  'Management Conntect': (l) => l.managementConnect,
  'Appointments': (l) => l.appointments,
  'Events': (l) => l.events,
  'Parent Teacher Meeting': (l) => l.parentTeacherMeeting,
  'Request For Entry': (l) => l.requestForEntry,
  'Complaints': (l) => l.complaints,
  'Transport Attendance': (_) => 'Transport Attendance',
};

/// One server-driven home menu tile; navigates to `/<routeState>`.
class DashboardTile extends StatelessWidget {
  const DashboardTile({
    required this.item,
    this.parentSlug,
    this.iconAsset,
    super.key,
  });

  final ParentRoleAction item;

  /// Route of the menu this tile sits in; null on the home screen.
  final String? parentSlug;

  /// Bundled icon shown instead of the server's, for menus that have their own artwork.
  final String? iconAsset;

  Widget _icon() {
    final asset = iconAsset;
    if (asset != null) {
      return asset.endsWith('.svg')
          ? SvgPicture.asset(asset, height: 50)
          : Image.asset(asset, height: 50);
    }
    final fallback = Image.asset(IcueAssets.logo, height: 50, width: 50);
    final url = item.icon;
    if (url.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        url,
        height: 50,
        placeholderBuilder: (_) => fallback,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.network(
      url,
      height: 50,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _names[item.displayName]?.call(ParentLocalizations.of(context)) ??
        item.displayName;
    final colors = item.colors
        .map((hex) => Color(int.parse(hex)))
        .toList(growable: false);
    return Material(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(
          parentSlug == null
              ? '/${item.routeState}'
              : '/$parentSlug/${item.routeState}',
        ),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors.length > 1 ? colors : [...colors, ...colors],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _icon()),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF414141),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
