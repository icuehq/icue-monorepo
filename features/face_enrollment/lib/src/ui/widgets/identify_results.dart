import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:face_enrollment/src/ui/widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';

class IdentifyResultsHeader extends StatelessWidget {
  const IdentifyResultsHeader({
    required this.attendanceResult,
    required this.identifiedStudents,
    super.key,
  });

  final AttendanceResult attendanceResult;
  final List<Student> identifiedStudents;

  @override
  Widget build(BuildContext context) {
    final result = attendanceResult;
    final matchPercentage = result.attendancePercentage.toStringAsFixed(1);

    return GlassCard(
      borderRadius: 20,
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECOGNITION SUMMARY',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: context.scheme.onSurface.withValues(alpha: 0.6),
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '$matchPercentage% MATCH',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3-Column Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Recognized',
                  value: '${identifiedStudents.length}',
                  valueColor: const Color(0xFF10B981),
                  context: context,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: context.scheme.onSurface.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _buildMetricTile(
                  label: 'Absent',
                  value: '${result.absentPersonIds.length}',
                  valueColor: context.scheme.onSurface.withValues(alpha: 0.7),
                  context: context,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: context.scheme.onSurface.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _buildMetricTile(
                  label: 'Unregistered',
                  value: '${result.unrecognizedFaceCount}',
                  valueColor: result.unrecognizedFaceCount > 0
                      ? context.scheme.error
                      : context.scheme.onSurface.withValues(alpha: 0.7),
                  context: context,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.totalRosterCount > 0
                  ? identifiedStudents.length / result.totalRosterCount
                  : 0.0,
              backgroundColor: context.scheme.onSurface.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
              ),
              minHeight: 6,
            ),
          ),
          if (result.unrecognizedFaceCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: context.scheme.error,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${result.unrecognizedFaceCount} unregistered face(s) detected during scan.',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.scheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color valueColor,
    required BuildContext context,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.scheme.onSurface.withValues(alpha: 0.55),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class IdentifiedStudentsList extends StatelessWidget {
  const IdentifiedStudentsList({
    required this.attendanceResult,
    required this.identifiedStudents,
    super.key,
  });

  final AttendanceResult attendanceResult;
  final List<Student> identifiedStudents;

  @override
  Widget build(BuildContext context) {
    if (identifiedStudents.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 36,
                color: context.scheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 8),
              Text(
                'No matching students identified in this scan',
                style: TextStyle(
                  color: context.scheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 15,
              color: Color(0xFF10B981),
            ),
            const SizedBox(width: 6),
            Text(
              'RECOGNIZED CANDIDATES (${identifiedStudents.length})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF10B981),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: identifiedStudents.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final student = identifiedStudents[index];
            final record = attendanceResult.present.firstWhere(
              (candidate) => candidate.personId == student.id.toString(),
              orElse: () => AttendanceRecord(
                personId: student.id.toString(),
                confidenceScore: 0.9,
                timestamp: DateTime.now(),
              ),
            );

            final score = (record.confidenceScore * 100).toStringAsFixed(1);

            return GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 16,
              borderColor: const Color(0xFF10B981).withValues(alpha: 0.2),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: context.scheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        backgroundImage:
                            student.photoUrl != null &&
                                student.photoUrl!.isNotEmpty
                            ? NetworkImage(student.photoUrl!)
                            : null,
                        child:
                            student.photoUrl == null ||
                                student.photoUrl!.isEmpty
                            ? Text(
                                student.name.isNotEmpty
                                    ? student.name[0].toUpperCase()
                                    : 'S',
                                style: TextStyle(
                                  color: context.scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ID: ${student.admissionNumber} • STD ${student.standard}-${student.section}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.scheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '$score%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
