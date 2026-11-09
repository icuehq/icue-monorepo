import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:flutter/material.dart';

class IdentifyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const IdentifyAppBar({
    required this.rosterSize,
    required this.statusText,
    this.onRefreshRoster,
    super.key,
  });

  final int rosterSize;
  final String statusText;
  final VoidCallback? onRefreshRoster;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: context.scheme.surface,
      surfaceTintColor: context.scheme.surfaceTint,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
        tooltip: 'Back to Directory',
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Biometric Identifier',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            statusText,
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
        if (rosterSize > 0)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 12,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  '$rosterSize Enrolled',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        if (onRefreshRoster != null)
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: context.scheme.onSurface.withValues(alpha: 0.65),
            ),
            tooltip: 'Reload Local Roster',
            onPressed: onRefreshRoster,
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

typedef IdentifyNavBar = IdentifyAppBar;
