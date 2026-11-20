import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class BranchesAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BranchesAppBar({required this.onLogout, super.key});

  final Future<void> Function() onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of this session?',
        ),
        actions: [
          IcueButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(false),
            variant: IcueButtonVariant.ghost,
          ),
          IcueButton(
            label: 'Sign Out',
            onPressed: () => Navigator.of(ctx).pop(true),
            variant: IcueButtonVariant.destructive,
          ),
        ],
      ),
    );

    if (confirm == true) {
      await onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0.5,
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
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: IcueButton(
            label: 'Sign Out',
            onPressed: () => _handleLogout(context),
            variant: IcueButtonVariant.destructive,
            leadingIcon: Icons.logout,
          ),
        ),
      ],
    );
  }
}
