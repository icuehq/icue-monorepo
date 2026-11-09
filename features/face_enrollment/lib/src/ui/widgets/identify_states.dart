import 'package:core_ui/core_ui.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:flutter/material.dart';

class PreparingState extends StatelessWidget {
  const PreparingState({
    required this.progress,
    required this.statusText,
    super.key,
  });

  final double progress;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).clamp(0, 100).toInt();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.scheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.scheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Initializing Face Recognition',
              style: TextStyle(
                color: context.scheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              statusText,
              style: TextStyle(
                color: context.scheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: context.scheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.scheme.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: context.scheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyRosterState extends StatelessWidget {
  const EmptyRosterState({
    required this.statusText,
    this.onSync,
    this.onBack,
    super.key,
  });

  final String statusText;
  final VoidCallback? onSync;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.face_retouching_off_rounded,
                size: 48,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Face Embeddings In Cache',
              style: TextStyle(
                color: context.scheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Local device storage has no registered student embeddings for face recognition. Please sync with the cloud or register students.',
              style: TextStyle(
                color: context.scheme.onSurface.withValues(alpha: 0.65),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onBack != null)
                  SizedBox(
                    width: 130,
                    child: AppButton(
                      label: 'Go Back',
                      variant: AppButtonVariant.outline,
                      leadingIcon: Icons.arrow_back_rounded,
                      onPressed: onBack,
                      isFullWidth: true,
                    ),
                  ),
                if (onBack != null && onSync != null) const SizedBox(width: 12),
                if (onSync != null)
                  SizedBox(
                    width: 150,
                    child: AppButton(
                      label: 'Sync Cloud',
                      leadingIcon: Icons.sync_rounded,
                      onPressed: onSync,
                      isFullWidth: true,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
