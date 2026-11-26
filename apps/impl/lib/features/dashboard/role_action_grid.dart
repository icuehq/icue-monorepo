import 'package:flutter/material.dart';
import 'package:impl/features/dashboard/dashboard_tile.dart';
import 'package:students/students.dart';

/// Responsive grid of server-driven menu tiles (2, 4 or 6 columns by width).
class RoleActionGrid extends StatelessWidget {
  const RoleActionGrid({
    required this.items,
    this.parentSlug,
    this.iconAssetFor,
    super.key,
  });

  final List<ParentRoleAction> items;

  /// Route of the menu the tiles belong to; null on the home screen.
  final String? parentSlug;

  /// Bundled icon for a tile, or null to use the server's.
  final String? Function(ParentRoleAction item)? iconAssetFor;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width < 600 ? 2 : (width < 900 ? 4 : 6);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 30),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          mainAxisExtent: 120,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => DashboardTile(
          key: ValueKey(items[i].id),
          item: items[i],
          parentSlug: parentSlug,
          iconAsset: iconAssetFor?.call(items[i]),
        ),
      );
    },
  );
}
