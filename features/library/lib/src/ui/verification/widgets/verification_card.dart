import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

class VerificationCard extends StatelessWidget {
  const VerificationCard({
    super.key,
    required this.verification,
    required this.onTap,
  });

  final LibraryVerification verification;
  final VoidCallback onTap;

  (Color, Color) _statusColors(ThemeData theme) {
    return switch (verification.status) {
      'approved' => (
        Colors.green.shade700,
        Colors.green.withValues(alpha: 0.12),
      ),
      'submitted' => (
        Colors.blue.shade700,
        Colors.blue.withValues(alpha: 0.12),
      ),
      _ => (Colors.orange.shade800, Colors.orange.withValues(alpha: 0.12)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusColor, statusBackground) = _statusColors(theme);
    final totalExpected = verification.expected.length;
    final totalScanned = verification.scanned.length;
    final progress = totalExpected > 0 ? (totalScanned / totalExpected) : 0.0;

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.fact_check_outlined,
                      color: statusColor,
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
                              verification.number,
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
                                color: statusBackground,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                verificationStatusLabel(verification.status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          verification.libraryName,
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
              // Progress indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    verification.status == 'approved'
                        ? Colors.green.shade700
                        : theme.colorScheme.primary,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metaPill(
                    context,
                    Icons.qr_code_scanner_rounded,
                    '$totalScanned / $totalExpected scanned',
                  ),
                  const SizedBox(width: 6),
                  _metaPill(
                    context,
                    Icons.shelves,
                    verification.shelf ?? 'All shelves',
                  ),
                  const Spacer(),
                  if (verification.verifiedDate != null)
                    Text(
                      verification.verifiedDate!.toDisplayDay(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
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
