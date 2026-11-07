import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:school_library/src/ui/routing/library_destinations.dart';

/// Tabs shown inside a page's app bar, one per screen of its navigation group.
class LibraryTabBar extends StatelessWidget implements PreferredSizeWidget {
  const LibraryTabBar({
    required this.tabs,
    required this.activePath,
    super.key,
  });

  final List<LibraryEntry> tabs;
  final String activePath;

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
          for (final tab in tabs) ...[
            InkWell(
              onTap: activePath == tab.path ? null : () => context.go(tab.path),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 3,
                      color: activePath == tab.path
                          ? foregroundColor
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  tab.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: activePath == tab.path
                        ? foregroundColor
                        : foregroundColor.withValues(alpha: 0.7),
                    fontWeight: activePath == tab.path
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
