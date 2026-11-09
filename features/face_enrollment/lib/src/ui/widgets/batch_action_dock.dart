import 'package:face_enrollment/src/providers/student_provider.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:face_enrollment/src/ui/widgets/batch_progress_dialog.dart';
import 'package:face_enrollment/src/ui/widgets/glass_card.dart';
import 'package:flutter/material.dart';

class BatchActionDock extends StatelessWidget {
  const BatchActionDock({required this.studentProvider, super.key});

  final StudentProvider studentProvider;

  @override
  Widget build(BuildContext context) {
    if (studentProvider.isLoading) {
      return const SizedBox.shrink();
    }

    final studentsWithPhoto = studentProvider.filteredStudents
        .where(
          (student) => student.photoUrl != null && student.photoUrl!.isNotEmpty,
        )
        .toList();
    final pendingStudents = studentsWithPhoto
        .where((student) => !studentProvider.hasEmbedding(student.id))
        .toList();

    if (pendingStudents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        borderRadius: 20,
        borderColor: context.scheme.primary.withValues(alpha: 0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.scheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: context.scheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BATCH ENROLLMENT',
                    style: TextStyle(
                      color: context.scheme.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${pendingStudents.length}${studentProvider.hasMore ? '+' : ''} pending',
                    style: TextStyle(
                      color: context.scheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  showBatchProgressDialog(context, studentProvider),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 38),
                backgroundColor: context.scheme.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: context.scheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'ENROLL (${pendingStudents.length}${studentProvider.hasMore ? '+' : ''})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
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
