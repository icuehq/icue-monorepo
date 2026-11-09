import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:face_enrollment/src/ui/widgets/glass_card.dart';
import 'package:flutter/material.dart';

class StudentCard extends StatelessWidget {
  const StudentCard({
    super.key,
    required this.student,
    required this.onTapFingerprint,
    this.isEnrolled = false,
  });

  final Student student;
  final VoidCallback onTapFingerprint;
  final bool isEnrolled;

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto =
        student.photoUrl != null && student.photoUrl!.isNotEmpty;

    // Status accent color: Green for enrolled, Primary for photo ready, Amber for no photo
    final Color statusColor = isEnrolled
        ? const Color(0xFF10B981)
        : (hasPhoto ? context.scheme.primary : const Color(0xFFF59E0B));

    final initials = student.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();

    final placeholderColor =
        Colors.primaries[student.id % Colors.primaries.length];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTapFingerprint,
        borderRadius: BorderRadius.circular(20),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          borderRadius: 20,
          borderColor: statusColor.withValues(alpha: isEnrolled ? 0.35 : 0.2),
          child: Row(
            children: [
              // Avatar with status ring
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.7),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(27),
                      child: hasPhoto
                          ? Image.network(
                              student.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholder(
                                    context,
                                    initials,
                                    placeholderColor,
                                  ),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: context.scheme.onSurface
                                          .withValues(alpha: 0.05),
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                context.scheme.primary,
                                              ),
                                        ),
                                      ),
                                    );
                                  },
                            )
                          : _buildPlaceholder(
                              context,
                              initials,
                              placeholderColor,
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.scheme.surface,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: isEnrolled
                          ? const Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Student details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      student.name,
                      style: TextStyle(
                        color: context.scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID: ${student.admissionNumber}',
                      style: TextStyle(
                        color: context.scheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildBadge(
                          'STD ${student.standard}',
                          context.scheme.onSurface.withValues(alpha: 0.08),
                          context.scheme.onSurface.withValues(alpha: 0.8),
                        ),
                        if (student.section.isNotEmpty)
                          _buildBadge(
                            'SEC ${student.section}',
                            context.scheme.onSurface.withValues(alpha: 0.08),
                            context.scheme.onSurface.withValues(alpha: 0.8),
                          ),
                        _buildStatusBadge(
                          isEnrolled: isEnrolled,
                          hasPhoto: hasPhoto,
                          statusColor: statusColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action button
              Tooltip(
                message: isEnrolled
                    ? 'Update face embedding'
                    : (hasPhoto
                          ? 'Enroll face embedding'
                          : 'Capture photo & enroll'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    isEnrolled
                        ? Icons.published_with_changes_rounded
                        : (hasPhoto
                              ? Icons.face_unlock_rounded
                              : Icons.add_a_photo_outlined),
                    color: statusColor,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, String initials, Color color) {
    return Container(
      color: color.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: context.scheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isEnrolled,
    required bool hasPhoto,
    required Color statusColor,
  }) {
    final String label;
    final IconData iconData;

    if (isEnrolled) {
      label = 'Enrolled';
      iconData = Icons.verified_rounded;
    } else if (hasPhoto) {
      label = 'Photo Ready';
      iconData = Icons.face_unlock_rounded;
    } else {
      label = 'No Photo';
      iconData = Icons.no_photography_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 11, color: statusColor),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
