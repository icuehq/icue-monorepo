import 'package:face_enrollment/src/providers/student_provider.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

void confirmLogout(BuildContext context, VoidCallback onConfirm) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.power_settings_new_rounded,
              size: 48,
              color: context.scheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Confirm Logout',
              style: TextStyle(
                color: context.scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to exit your administrative session?',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IcueButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                  variant: IcueButtonVariant.ghost,
                ),
                const SizedBox(width: 8),
                IcueButton(
                  label: 'Logout',
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                  variant: IcueButtonVariant.destructive,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void handleSyncEmbeddings(
  BuildContext context,
  StudentProvider studentProvider,
) {
  final syncFuture = studentProvider.syncEmbeddingsFromServer();

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return FutureBuilder<int>(
        future: syncFuture,
        builder: (context, snapshot) {
          final isProcessing =
              snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError;
          final data = snapshot.data;

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        isProcessing
                            ? Icons.sync_rounded
                            : hasError
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: isProcessing
                            ? context.scheme.primary
                            : hasError
                            ? context.scheme.error
                            : Colors.green.shade700,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isProcessing
                              ? 'Syncing Embeddings...'
                              : hasError
                              ? 'Sync Failed'
                              : 'Sync Completed',
                          style: TextStyle(
                            color: context.scheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (isProcessing) ...[
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Downloading face embeddings from the server and updating local storage cache...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (hasError) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.scheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.scheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        snapshot.error.toString().replaceAll('Exception: ', ''),
                        style: TextStyle(
                          color: context.scheme.error,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.scheme.onSurface.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.scheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          summaryStat(
                            label: 'Synced',
                            value: data.toString(),
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All synchronized embeddings are stored in local preferences and ready for scanning.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isProcessing)
                        SizedBox(
                          width: 100,
                          child: IcueButton(
                            label: 'Close',
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              studentProvider.resetAndFetch();
                            },
                            isFullWidth: true,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget summaryStat({
  required String label,
  required String value,
  required Color color,
}) {
  return Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
    ],
  );
}
