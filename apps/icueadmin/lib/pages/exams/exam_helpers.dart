import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_info.dart';
import '../../providers/auth_provider.dart';
import '../../services/hive_service.dart';

class ExamClassOption {
  ExamClassOption({
    required this.classId,
    required this.standard,
    required this.sections,
    this.subjectInfo,
  });

  final int classId;
  final String standard;
  final List<String> sections;
  final List<SubjectInfo>? subjectInfo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamClassOption &&
          runtimeType == other.runtimeType &&
          classId == other.classId;

  @override
  int get hashCode => classId.hashCode;
}

class ExamHelpers {
  static String getCurrentAcademicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  static List<String> getAvailableAcademicYears({
    int startYear = 2016,
    bool includeAll = true,
  }) {
    final now = DateTime.now();
    final currentStart = now.month >= 4 ? now.year : now.year - 1;
    final endYear = currentStart;
    final minYear = startYear <= endYear ? startYear : endYear;

    final List<String> years = [];
    if (includeAll) {
      years.add('All years');
    }

    for (int y = endYear; y >= minYear; y--) {
      years.add('$y-${y + 1}');
    }

    return years;
  }

  static List<ExamClassOption> getAvailableClasses(BuildContext context) {
    final user = HiveService.userInfoBox.values.firstOrNull;
    final Map<int, ExamClassOption> map = {};

    if (user?.classes is List && (user!.classes as List).isNotEmpty) {
      for (final c in user.classes as List) {
        if (c is UserClass && c.classId != 0) {
          if (!map.containsKey(c.classId)) {
            map[c.classId] = ExamClassOption(
              classId: c.classId,
              standard: c.standard,
              sections: List<String>.from(c.sections),
              subjectInfo: c.subjectInfo != null
                  ? List<SubjectInfo>.from(c.subjectInfo!)
                  : null,
            );
          } else {
            final existing = map[c.classId]!;
            for (final sec in c.sections) {
              if (!existing.sections.contains(sec)) {
                existing.sections.add(sec);
              }
            }
          }
        } else if (c is Map) {
          final id = c['ClassId'] is int
              ? c['ClassId'] as int
              : int.tryParse(c['ClassId']?.toString() ?? '');
          if (id != null && id != 0) {
            if (!map.containsKey(id)) {
              map[id] = ExamClassOption(
                classId: id,
                standard: c['Standard']?.toString() ?? '',
                sections: List<String>.from(c['Sections'] ?? []),
              );
            } else {
              final existing = map[id]!;
              final rawSections = c['Sections'] is List
                  ? c['Sections'] as List
                  : [];
              for (final sec in rawSections) {
                final secStr = sec.toString();
                if (!existing.sections.contains(secStr)) {
                  existing.sections.add(secStr);
                }
              }
            }
          }
        }
      }
      if (map.isNotEmpty) return map.values.toList();
    }

    final authProvider = context.read<AuthProvider>();
    if (authProvider.assignedEntityClasses.isNotEmpty) {
      for (final c in authProvider.assignedEntityClasses) {
        if (c.classId != 0) {
          if (!map.containsKey(c.classId)) {
            map[c.classId] = ExamClassOption(
              classId: c.classId,
              standard: c.standard,
              sections: List<String>.from(c.sections),
            );
          } else {
            final existing = map[c.classId]!;
            for (final sec in c.sections) {
              if (!existing.sections.contains(sec)) {
                existing.sections.add(sec);
              }
            }
          }
        }
      }
      if (map.isNotEmpty) return map.values.toList();
    }

    return [];
  }

  static List<String> getSubjectsForClass(
    ExamClassOption? classOption,
    String? section,
  ) {
    if (classOption?.subjectInfo != null && section != null) {
      final subInfo = classOption!.subjectInfo!.firstWhere(
        (s) => s.section.toLowerCase() == section.toLowerCase(),
        orElse: () => SubjectInfo(section: section, subjects: []),
      );
      if (subInfo.subjects.isNotEmpty) {
        return subInfo.subjects.map((s) => s.subject).toList();
      }
    }
    // Default fallback subjects
    return [
      'English',
      'Mathematics',
      'Science',
      'Social Studies',
      'Hindi',
      'Physics',
      'Chemistry',
      'Biology',
      'Computer Science',
    ];
  }

  static Color getGradeColor(String? grade) {
    switch (grade?.toUpperCase()) {
      case 'A+':
      case 'A':
        return const Color(0xFF10B981); // Emerald
      case 'B+':
      case 'B':
        return const Color(0xFF3B82F6); // Blue
      case 'C+':
      case 'C':
        return const Color(0xFFF59E0B); // Amber
      case 'D':
        return const Color(0xFFF97316); // Orange
      case 'F':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  static Color getResultColor(String? result) {
    return (result?.toUpperCase() == 'PASS')
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
  }

  static Widget buildRankBadge(int? rank) {
    if (rank == null) return const SizedBox.shrink();

    if (rank == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, size: 14, color: Color(0xFFD97706)),
            SizedBox(width: 4),
            Text(
              '1st',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB45309),
              ),
            ),
          ],
        ),
      );
    } else if (rank == 2) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF94A3B8)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.military_tech, size: 14, color: Color(0xFF64748B)),
            SizedBox(width: 4),
            Text(
              '2nd',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      );
    } else if (rank == 3) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDD5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFB923C)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, size: 14, color: Color(0xFFEA580C)),
            SizedBox(width: 4),
            Text(
              '3rd',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFC2410C),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '#$rank',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}
