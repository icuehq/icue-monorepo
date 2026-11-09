import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:flutter/material.dart';

class StudentDirectoryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const StudentDirectoryAppBar({
    required this.userName,
    required this.onIdentify,
    required this.onSync,
    required this.onLogout,
    super.key,
  });

  final String userName;
  final VoidCallback onIdentify;
  final VoidCallback onSync;
  final VoidCallback onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final initials = userName.trim().isNotEmpty
        ? userName
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .map((part) => part[0])
              .take(2)
              .join()
              .toUpperCase()
        : 'AD';

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: context.scheme.surface,
      surfaceTintColor: context.scheme.surfaceTint,
      leadingWidth: 54,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: context.scheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
      titleSpacing: 12,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Student Directory',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: context.scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Identify Student Face',
          style: IconButton.styleFrom(
            backgroundColor: context.scheme.primary.withValues(alpha: 0.1),
            foregroundColor: context.scheme.primary,
          ),
          icon: const Icon(Icons.camera_front_rounded, size: 20),
          onPressed: onIdentify,
        ),
        IconButton(
          tooltip: 'Sync Server Embeddings',
          icon: Icon(
            Icons.sync_rounded,
            color: context.scheme.onSurface.withValues(alpha: 0.7),
            size: 21,
          ),
          onPressed: onSync,
        ),
        IconButton(
          tooltip: 'Logout',
          icon: Icon(
            Icons.logout_rounded,
            color: context.scheme.onSurface.withValues(alpha: 0.6),
            size: 20,
          ),
          onPressed: onLogout,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: context.scheme.onSurface.withValues(alpha: 0.07),
        ),
      ),
    );
  }
}
