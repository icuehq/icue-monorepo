import 'package:face_enrollment/src/providers/student_provider.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:face_enrollment/src/ui/widgets/custom_button.dart';
import 'package:face_enrollment/src/ui/widgets/directory_dialogs.dart';
import 'package:flutter/material.dart';

void showBatchProgressDialog(
  BuildContext context,
  StudentProvider studentProvider,
) {
  studentProvider.generateAndUploadBatchEmbeddings();

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return PopScope(
        canPop: false,
        child: ListenableBuilder(
          listenable: studentProvider.batch,
          builder: (context, child) {
            final batch = studentProvider.batch;
            final isProcessing = batch.isRunning;
            final progress = batch.fraction;
            final message = batch.message;
            final successCount = batch.succeeded;
            final failureCount = batch.failed;
            final totalCount = batch.total;

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
                              ? Icons.bolt_rounded
                              : Icons.check_circle_outline_rounded,
                          color: isProcessing
                              ? context.scheme.primary
                              : Colors.green.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isProcessing
                                ? 'Generating Embeddings...'
                                : 'Batch Process Completed',
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.scheme.primary,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress: ${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${successCount + failureCount} / $totalCount',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.scheme.onSurface.withValues(
                            alpha: 0.02,
                          ),
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
                              label: 'Total',
                              value: totalCount.toString(),
                              color: Colors.grey.shade600,
                            ),
                            summaryStat(
                              label: 'Success',
                              value: successCount.toString(),
                              color: Colors.green.shade700,
                            ),
                            summaryStat(
                              label: 'Failed',
                              value: failureCount.toString(),
                              color: context.scheme.error,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.scheme.onSurface.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: isProcessing
                              ? Colors.grey.shade600
                              : context.scheme.onSurface,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isProcessing)
                          TextButton.icon(
                            onPressed: batch.cancelRequested
                                ? null
                                : batch.requestCancel,
                            icon: const Icon(Icons.cancel_rounded, size: 18),
                            label: const Text('Cancel'),
                            style: TextButton.styleFrom(
                              foregroundColor: context.scheme.error,
                            ),
                          )
                        else
                          SizedBox(
                            width: 100,
                            child: CustomButton(
                              text: 'Close',
                              height: 40,
                              borderRadius: 12,
                              fontSize: 14,
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                studentProvider.resetAndFetch();
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
