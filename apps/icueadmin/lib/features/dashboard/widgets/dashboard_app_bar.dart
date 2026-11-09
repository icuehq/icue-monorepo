import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({
    required this.user,
    required this.onLogout,
    required this.environment,
    super.key,
  });

  final UserInfo user;
  final VoidCallback onLogout;
  final ApiEnvironment environment;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDev = environment.isDev;

    return AppBar(
      elevation: 1,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/logo.png',
            height: 32,
            errorBuilder: (_, _, _) => const Icon(Icons.school, size: 28),
          ),
          const SizedBox(width: 10),
          const Text(
            'iCue Admin',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDev ? Colors.orange.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDev ? Colors.orange.shade600 : Colors.green.shade600,
              ),
            ),
            child: Text(
              environment.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDev ? Colors.orange.shade900 : Colors.green.shade900,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: AppButton(
            label: 'Sign Out',
            onPressed: onLogout,
            variant: AppButtonVariant.destructive,
            leadingIcon: Icons.logout,
          ),
        ),
      ],
    );
  }
}
