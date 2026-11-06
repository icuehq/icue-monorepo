import 'package:admin_ui/src/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A tab of a [ModuleDestination]: one screen of the group it belongs to.
class ModuleTab {
  const ModuleTab({required this.label, required this.path});

  final String label;
  final String path;
}

/// One side-navigation entry of a [ModuleShell]; [group] heads a run of entries.
///
/// With two or more [tabs] the shell shows a tab strip above the open screen.
class ModuleDestination {
  const ModuleDestination({
    required this.label,
    required this.path,
    required this.icon,
    this.group,
    this.badge,
    this.tabs = const [],
  });

  final String label;
  final String path;
  final IconData icon;
  final String? group;
  final Widget? badge;
  final List<ModuleTab> tabs;
}

/// Wraps a module's pages with a persistent side navigation on wide screens.
///
/// On phones it returns [child] untouched, so each module keeps its home grid.
class ModuleShell extends StatelessWidget {
  const ModuleShell({
    required this.title,
    required this.homePath,
    required this.location,
    required this.destinations,
    required this.child,
    this.icon,
    this.exitPath = '/',
    this.exitLabel = 'Dashboard',
    super.key,
  });

  final String title;
  final IconData? icon;

  /// Where the back-to-dashboard entry goes.
  final String exitPath;
  final String exitLabel;
  final String homePath;

  /// Current route path, used to highlight the open entry.
  final String location;
  final List<ModuleDestination> destinations;
  final Widget child;

  bool _matches(String path) =>
      location == path || (path != homePath && location.startsWith('$path/'));

  bool _selected(ModuleDestination destination) =>
      _matches(destination.path) ||
      destination.tabs.any((tab) => _matches(tab.path));

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) return child;
    final theme = Theme.of(context);
    final tabs =
        destinations.where(_selected).firstOrNull?.tabs ?? const <ModuleTab>[];
    String? group;
    final entries = <Widget>[];

    for (final destination in destinations) {
      if (destination.group != null && destination.group != group) {
        group = destination.group;
        entries.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 6),
            child: Text(
              group!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.75,
                ),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                fontSize: 11,
              ),
            ),
          ),
        );
      }

      final isSelected = _selected(destination);
      final activeColor = theme.colorScheme.primary;
      final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.85);
      final inactiveIconColor = theme.colorScheme.onSurfaceVariant;

      entries.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Material(
            color: isSelected
                ? activeColor.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go(destination.path),
              hoverColor: activeColor.withValues(alpha: 0.04),
              splashColor: activeColor.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      destination.icon,
                      size: 20,
                      color: isSelected ? activeColor : inactiveIconColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected ? activeColor : inactiveColor,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (destination.badge != null) ...[
                      const SizedBox(width: 8),
                      destination.badge!,
                    ],
                    if (isSelected)
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 270,
          child: Material(
            color: theme.colorScheme.surface,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => context.go(exitPath),
                          hoverColor: theme.colorScheme.onSurface.withValues(
                            alpha: 0.04,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_rounded,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  exitLabel,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon ?? Icons.dashboard_customize_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Workspace',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.45,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: entries,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        VerticalDivider(
          width: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        Expanded(
          child: tabs.length > 1
              ? Column(
                  children: [
                    _TabStrip(tabs: tabs, selected: _matches),
                    Expanded(child: child),
                  ],
                )
              : child,
        ),
      ],
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.tabs, required this.selected});

  final List<ModuleTab> tabs;
  final bool Function(String path) selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
        child: Row(
          children: [
            for (final tab in tabs)
              InkWell(
                onTap: () => context.go(tab.path),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 3,
                        color: selected(tab.path)
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    tab.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected(tab.path)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
