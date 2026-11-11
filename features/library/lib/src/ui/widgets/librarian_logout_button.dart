import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Logout for librarians, who have no dashboard to sign out from. Renders nothing for other roles.
class LibrarianLogoutButton extends StatelessWidget {
  const LibrarianLogoutButton({this.expanded = false, super.key});

  /// Full-width labelled entry (side navigation) instead of an icon.
  final bool expanded;

  Future<void> _confirm(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isLibrarian) {
      return const SizedBox.shrink();
    }
    return expanded
        ? ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () => _confirm(context),
          )
        : IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _confirm(context),
          );
  }
}
