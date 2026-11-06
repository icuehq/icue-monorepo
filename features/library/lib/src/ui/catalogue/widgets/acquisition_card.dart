import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

class AcquisitionCard extends StatelessWidget {
  const AcquisitionCard({
    super.key,
    required this.acquisition,
    required this.libraryName,
  });

  final LibraryAcquisition acquisition;
  final String libraryName;

  (Color, Color) _typeColors(ThemeData theme) {
    return switch (acquisition.type) {
      'donation' => (
        Colors.purple.shade700,
        Colors.purple.withValues(alpha: 0.12),
      ),
      'opening_stock' => (
        Colors.teal.shade700,
        Colors.teal.withValues(alpha: 0.12),
      ),
      _ => (
        theme.colorScheme.primary,
        theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (typeColor, typeBackground) = _typeColors(theme);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: typeBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: typeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            acquisition.number,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: typeBackground,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: typeColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              humanizeStatus(acquisition.type),
                              style: TextStyle(
                                color: typeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        libraryName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _metaPill(
                  context,
                  Icons.collections_bookmark_outlined,
                  '${acquisition.quantity} ${acquisition.quantity == 1 ? 'copy' : 'copies'}',
                ),
                if (acquisition.vendorOrDonor != null &&
                    acquisition.vendorOrDonor!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _metaPill(
                    context,
                    Icons.person_outline_rounded,
                    acquisition.vendorOrDonor!,
                  ),
                ],
                if (acquisition.date != null) ...[
                  const SizedBox(width: 6),
                  _metaPill(
                    context,
                    Icons.event_outlined,
                    acquisition.date!.toDisplayDay(),
                  ),
                ],
                const Spacer(),
                if (acquisition.price > 0)
                  Text(
                    acquisition.price.toRupees(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaPill(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
