import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:impl/features/dashboard/role_action_grid.dart';
import 'package:provider/provider.dart';
import 'package:students/students.dart';

/// A menu page (School Connect, Academics) listing the sub-actions the server
/// enabled for the student under [routeState].
class SubMenuPage extends StatelessWidget {
  const SubMenuPage({
    required this.routeState,
    required this.title,
    this.iconAssetFor,
    super.key,
  });

  final String routeState;
  final String title;

  /// Bundled icon for a tile, or null to use the server's.
  final String? Function(ParentRoleAction item)? iconAssetFor;

  @override
  Widget build(BuildContext context) {
    final students = context.watch<ParentStudentsProvider>();
    final items =
        students.roleActions
            .where((a) => a.routeState == routeState)
            .firstOrNull
            ?.subActions
            .where((a) => a.isVisible)
            .toList() ??
        <ParentRoleAction>[];
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(title),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: IcueSheetBody(
        loading: students.actionsLoading,
        child: SingleChildScrollView(
          child: RoleActionGrid(
            items: items,
            parentSlug: routeState,
            iconAssetFor: iconAssetFor,
          ),
        ),
      ),
    );
  }
}
