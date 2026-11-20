import 'dart:io';

import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/providers/embedding_provider.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:face_enrollment/src/ui/widgets/glass_card.dart';
import 'package:flutter/material.dart';

class StudentHeaderCard extends StatelessWidget {
  const StudentHeaderCard({
    required this.student,
    required this.embeddingProvider,
    super.key,
  });

  final Student student;
  final EmbeddingProvider embeddingProvider;

  @override
  Widget build(BuildContext context) {
    final initials = student.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();

    final hasPhoto =
        (student.photoUrl != null && student.photoUrl!.isNotEmpty) ||
        embeddingProvider.localImagePath != null;

    final String sourceLabel =
        embeddingProvider.imageSource ??
        (student.photoUrl != null && student.photoUrl!.isNotEmpty
            ? 'Server URL'
            : 'No Photo');

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 16,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: context.scheme.primary.withValues(alpha: 0.12),
            backgroundImage: embeddingProvider.localImagePath != null
                ? FileImage(File(embeddingProvider.localImagePath!))
                : (student.photoUrl != null && student.photoUrl!.isNotEmpty
                      ? NetworkImage(student.photoUrl!) as ImageProvider
                      : null),
            child: !hasPhoto
                ? Text(
                    initials,
                    style: TextStyle(
                      color: context.scheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.scheme.onSurface,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${student.admissionNumber} • STD ${student.standard}-${student.section}',
                  style: TextStyle(
                    color: context.scheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color:
                  (hasPhoto ? context.scheme.primary : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    (hasPhoto
                            ? context.scheme.primary
                            : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasPhoto
                      ? (embeddingProvider.imageSource == 'Camera'
                            ? Icons.camera_alt_outlined
                            : Icons.image_outlined)
                      : Icons.no_photography_outlined,
                  size: 11,
                  color: hasPhoto
                      ? context.scheme.primary
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 4),
                Text(
                  sourceLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: hasPhoto
                        ? context.scheme.primary
                        : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
