import 'package:auth/auth.dart';
import 'package:flutter/material.dart';

class ModuleCardDetails {
  const ModuleCardDetails({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.badge,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String badge;
}

ModuleCardDetails getModuleCardDetails(RoleActions action, ColorScheme scheme) {
  switch (action.routeState) {
    case 'layout.stationeryinventory':
      return ModuleCardDetails(
        title: action.displayName.isNotEmpty
            ? action.displayName
            : 'Stationery & Supplies',
        description: 'Check stock levels, approve item requests, and track school supplies.',
        icon: Icons.inventory_2_rounded,
        accentColor: scheme.primary,
        badge: 'Supplies',
      );
    case 'layout.library':
      return ModuleCardDetails(
        title: action.displayName.isNotEmpty
            ? action.displayName
            : 'School Library',
        description: 'Issue and return books, search the catalog, and view student reading history.',
        icon: Icons.local_library_rounded,
        accentColor: const Color(0xFF1E88E5),
        badge: 'Library',
      );
    default:
      return ModuleCardDetails(
        title: action.displayName.isNotEmpty ? action.displayName : action.name,
        description: action.name.isNotEmpty
            ? action.name
            : 'Manage school operations for this module.',
        icon: Icons.apps_rounded,
        accentColor: scheme.secondary,
        badge: 'Module',
      );
  }
}

class HomeModuleCard extends StatelessWidget {
  const HomeModuleCard({required this.action, required this.onTap, super.key});

  final RoleActions action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = getModuleCardDetails(action, scheme);
    final isEnabled = onTap != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: details.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      details.icon,
                      color: details.accentColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                details.title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: details.accentColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                details.badge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: details.accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          details.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? details.accentColor.withValues(alpha: 0.08)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEnabled ? 'Open Module' : 'Access Restricted',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isEnabled
                            ? details.accentColor
                            : scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    Icon(
                      isEnabled
                          ? Icons.arrow_forward_rounded
                          : Icons.lock_outline_rounded,
                      size: 16,
                      color: isEnabled
                          ? details.accentColor
                          : scheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
