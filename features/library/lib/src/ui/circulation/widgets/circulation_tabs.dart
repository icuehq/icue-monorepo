import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:school_library/src/ui/routing/library_routes.dart';

enum CirculationTab {
  loans('Loans', LibraryRoutes.libraryCirculation),
  reservations('Reservations', LibraryRoutes.libraryReservations),
  fines('Fines', LibraryRoutes.libraryFines),
  incidents('Lost & damaged', LibraryRoutes.libraryIncidents);

  const CirculationTab(this.label, this.path);

  final String label;
  final String path;
}

/// Persistent tabs inside the circulation app bar across loans, reservations, fines, and incidents.
class CirculationTabBar extends StatelessWidget implements PreferredSizeWidget {
  const CirculationTabBar({required this.activeTab, super.key});

  final CirculationTab activeTab;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final tab in CirculationTab.values) ...[
            InkWell(
              onTap: activeTab == tab ? null : () => context.go(tab.path),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 3,
                      color: activeTab == tab
                          ? foregroundColor
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  tab.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: activeTab == tab
                        ? foregroundColor
                        : foregroundColor.withValues(alpha: 0.7),
                    fontWeight: activeTab == tab
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
