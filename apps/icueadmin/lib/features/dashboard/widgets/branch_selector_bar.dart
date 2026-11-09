import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class BranchSelectorBar extends StatelessWidget {
  const BranchSelectorBar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final zonalBranch = auth.selectedBranch;

    if (zonalBranch == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              zonalBranch.schoolName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          AppButton(
            label: 'Change',
            onPressed: () {
              context.push(AppRoutes.branches);
            },
          ),
        ],
      ),
    );
  }
}
