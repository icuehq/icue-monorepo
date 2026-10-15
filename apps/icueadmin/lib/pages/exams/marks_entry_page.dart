import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/exam_schedule.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import 'exam_helpers.dart';
import 'student_marks_entry_page.dart';

class MarksEntryPage extends StatefulWidget {
  const MarksEntryPage({super.key});

  @override
  State<MarksEntryPage> createState() => _MarksEntryPageState();
}

class _MarksEntryPageState extends State<MarksEntryPage> {
  String selectedAcademicYear = ExamHelpers.getCurrentAcademicYear();
  String? selectedExamName;
  ExamClassOption? selectedClass;
  String? selectedSection;
  ExamSchedule? selectedSchedule;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  void _initData() {
    final examProvider = context.read<ExamProvider>();
    final authProvider = context.read<AuthProvider>();
    final classes = ExamHelpers.getAvailableClasses(context);

    // Fetch prep exams for the Exam Name dropdown
    examProvider.getPrepExams(selectedAcademicYear);

    // Fetch assigned entity classes if not yet loaded
    if (classes.isEmpty && authProvider.assignedEntityClasses.isEmpty) {
      authProvider.getAssignedEntities(context);
    }

    // If a schedule was pre-selected from schedules page
    if (examProvider.selectedSchedule != null) {
      final s = examProvider.selectedSchedule!;
      selectedAcademicYear = s.academicYear;
      selectedExamName = s.examName.isNotEmpty ? s.examName : null;
      selectedClass = classes.firstWhereOrNull((c) => c.classId == s.classId);
      selectedSection = s.section.isNotEmpty ? s.section : null;
      selectedSchedule = s;
    } else {
      examProvider.clearSchedules();
    }
  }

  Future<void> _fetchSchedules() async {
    final examProvider = context.read<ExamProvider>();

    final hasExam = selectedExamName != null && selectedExamName!.isNotEmpty;
    final hasClass = selectedClass != null && selectedClass!.classId > 0;
    final hasSection = selectedSection != null && selectedSection!.isNotEmpty;

    // Call getExamSchedules API ONLY when Exam Name, Class, AND Section are all selected
    if (!hasExam || !hasClass || !hasSection) {
      examProvider.clearSchedules();
      if (selectedSchedule != null) {
        setState(() => selectedSchedule = null);
      }
      return;
    }

    await examProvider.getExamSchedules(
      academicYear: selectedAcademicYear,
      examName: selectedExamName!,
      classId: selectedClass!.classId,
      section: selectedSection!,
    );

    if (mounted) {
      if (selectedSchedule != null) {
        final match = examProvider.schedules.firstWhereOrNull(
          (s) => s.id == selectedSchedule!.id,
        );
        final isMatchPublished =
            match != null &&
            (match.status?.trim().toLowerCase() == 'published' ||
                (match.status == null && match.isPublished));
        if (isMatchPublished) {
          setState(() => selectedSchedule = match);
        } else {
          setState(() => selectedSchedule = null);
        }
      } else {
        final published = examProvider.schedules.where((s) {
          final status = s.status?.trim().toLowerCase();
          return status == 'published' || (status == null && s.isPublished);
        }).toList();
        if (published.length == 1) {
          setState(() => selectedSchedule = published.first);
        } else {
          setState(() {});
        }
      }
    }
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    DropdownButtonBuilder? selectedItemBuilder,
    bool isEnabled = true,
  }) {
    final hasValue = value != null && items.any((i) => i.value == value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isEnabled
                ? const Color(0xFF334155)
                : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isEnabled ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isEnabled
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: hasValue ? value : null,
              selectedItemBuilder: selectedItemBuilder,
              menuMaxHeight: 350,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isEnabled
                    ? const Color(0xFF475569)
                    : const Color(0xFF94A3B8),
                size: 20,
              ),
              hint: Text(
                hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: isEnabled
                      ? const Color(0xFF475569)
                      : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w400,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              items: isEnabled ? items : null,
              onChanged: isEnabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }

  void _onContinue() {
    if (selectedSchedule == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentMarksEntryPage(
          schedule: selectedSchedule!,
          academicYear: selectedAcademicYear,
          className: selectedClass?.standard,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final examProvider = context.watch<ExamProvider>();
    context.watch<AuthProvider>();
    final classes = ExamHelpers.getAvailableClasses(context);

    // If user has no assigned classes (e.g. Branch Admin), derive from loaded schedules
    if (classes.isEmpty && examProvider.schedules.isNotEmpty) {
      final scheduleClassesMap = <int, ExamClassOption>{};
      for (final s in examProvider.schedules) {
        if (s.classId > 0) {
          if (!scheduleClassesMap.containsKey(s.classId)) {
            scheduleClassesMap[s.classId] = ExamClassOption(
              classId: s.classId,
              standard: (s.standard != null && s.standard!.isNotEmpty)
                  ? s.standard!
                  : 'Class ${s.classId}',
              sections: s.section.isNotEmpty ? [s.section] : [],
            );
          } else {
            if (s.section.isNotEmpty &&
                !scheduleClassesMap[s.classId]!.sections.contains(s.section)) {
              scheduleClassesMap[s.classId]!.sections.add(s.section);
            }
          }
        }
      }
      classes.addAll(scheduleClassesMap.values);
    }

    if (selectedSchedule != null &&
        selectedClass == null &&
        classes.isNotEmpty) {
      selectedClass = classes.firstWhereOrNull(
        (c) => c.classId == selectedSchedule!.classId,
      );
    }

    final matchingClass = classes.firstWhereOrNull(
      (c) => c.classId == selectedClass?.classId,
    );
    final availableYears = ExamHelpers.getAvailableAcademicYears(
      includeAll: false,
    );
    if (!availableYears.contains(selectedAcademicYear)) {
      availableYears.insert(0, selectedAcademicYear);
    }
    final matchingYear = availableYears.contains(selectedAcademicYear)
        ? selectedAcademicYear
        : availableYears.firstOrNull;

    // Dynamic list of exam names populated from getPrepExams API
    final List<String> allExamNames = [];
    for (final e in examProvider.prepExams) {
      final name = e.examName ?? '';
      if (name.isNotEmpty && !allExamNames.contains(name)) {
        allExamNames.add(name);
      }
    }
    if (selectedExamName != null && !allExamNames.contains(selectedExamName)) {
      allExamNames.add(selectedExamName!);
    }

    // Section options strictly from the selected class
    final List<String> sectionOptions = matchingClass?.sections ?? [];
    final effectiveSection =
        (selectedSection != null && sectionOptions.contains(selectedSection))
        ? selectedSection
        : null;

    // Filter schedules for published exams
    final filteredSchedules = examProvider.schedules.where((s) {
      if (selectedAcademicYear != 'All years' &&
          s.academicYear.isNotEmpty &&
          s.academicYear != selectedAcademicYear) {
        return false;
      }
      if (selectedExamName != null && selectedExamName!.isNotEmpty) {
        if (s.examName.trim().toLowerCase() !=
            selectedExamName!.trim().toLowerCase()) {
          return false;
        }
      }
      if (matchingClass != null && s.classId != matchingClass.classId) {
        return false;
      }
      if (effectiveSection != null &&
          s.section.trim().toLowerCase() !=
              effectiveSection.trim().toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

    // Display data only "Status": "Published"
    final availableSchedules = filteredSchedules.where((s) {
      final status = s.status?.trim().toLowerCase();
      return status == 'published' || (status == null && s.isPublished);
    }).toList();

    final matchingSchedule = availableSchedules.firstWhereOrNull(
      (s) => s.id == selectedSchedule?.id,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Rapid Marks Entry')),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: selectedSchedule == null ? null : _onContinue,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue to Enter Marks',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Configuration Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exam Configuration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Select exam criteria to load subjects',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (examProvider.loading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),

                    // Academic Year & Exam Name
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 600;

                        final academicYearField = _buildDropdownField<String>(
                          label: 'Academic Year',
                          value: matchingYear,
                          hint: 'Select year',
                          selectedItemBuilder: (context) {
                            return availableYears.map((year) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  year,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              );
                            }).toList();
                          },
                          items: availableYears.map((year) {
                            final isSelected = year == matchingYear;
                            return DropdownMenuItem(
                              value: year,
                              child: Row(
                                children: [
                                  if (isSelected) ...[
                                    const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Color(0xFF1E293B),
                                    ),
                                    const SizedBox(width: 8),
                                  ] else ...[
                                    const SizedBox(width: 24),
                                  ],
                                  Text(
                                    year,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null && val != selectedAcademicYear) {
                              setState(() {
                                selectedAcademicYear = val;
                                selectedExamName = null;
                                selectedClass = null;
                                selectedSection = null;
                                selectedSchedule = null;
                              });
                              examProvider.clearSchedules();
                              examProvider.getPrepExams(val);
                            }
                          },
                        );

                        final examNameField = _buildDropdownField<String>(
                          label: 'Exam Name',
                          value:
                              (selectedExamName != null &&
                                  allExamNames.contains(selectedExamName))
                              ? selectedExamName
                              : null,
                          hint: 'Select exam',
                          items: allExamNames
                              .map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedExamName = val;
                              selectedSchedule = null;
                            });
                            // Only fetch schedules if both class and section are also selected
                            if (selectedClass != null &&
                                selectedSection != null) {
                              _fetchSchedules();
                            } else {
                              examProvider.clearSchedules();
                            }
                          },
                        );

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              academicYearField,
                              const SizedBox(height: 14),
                              examNameField,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: academicYearField),
                            const SizedBox(width: 14),
                            Expanded(child: examNameField),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // Class & Section
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 600;

                        final classField = _buildDropdownField<ExamClassOption>(
                          label: 'Class / Standard',
                          value: matchingClass,
                          hint: 'Select class',
                          items: classes
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.standard),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedClass = val;
                              selectedSection =
                                  null; // Reset section when class changes
                              selectedSchedule = null;
                            });
                            examProvider.clearSchedules();
                            // Do not fetch schedules yet; wait until section is selected!
                          },
                        );

                        final sectionField = _buildDropdownField<String>(
                          label: 'Section',
                          value: effectiveSection,
                          isEnabled: selectedClass != null,
                          hint: selectedClass == null
                              ? 'Select class first'
                              : (sectionOptions.isEmpty
                                    ? 'No sections'
                                    : 'Select section'),
                          items: sectionOptions
                              .map(
                                (sec) => DropdownMenuItem(
                                  value: sec,
                                  child: Text(sec),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                selectedSection = val;
                                selectedSchedule = null;
                              });
                              // Section selected! Now fetch schedules
                              _fetchSchedules();
                            }
                          },
                        );

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              classField,
                              const SizedBox(height: 14),
                              sectionField,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: classField),
                            const SizedBox(width: 14),
                            Expanded(child: sectionField),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // Published Exam Schedule Field
                    _buildDropdownField<ExamSchedule>(
                      label: 'Published Exam Subject',
                      value: matchingSchedule,
                      isEnabled: selectedSection != null,
                      hint: selectedSection == null
                          ? 'Select section first'
                          : (availableSchedules.isEmpty
                                ? 'No published exams found'
                                : 'Select published subject'),
                      selectedItemBuilder: (context) {
                        return availableSchedules.map((s) {
                          final title = s.examDate.isNotEmpty
                              ? '${s.subject} (${s.examDate})'
                              : s.subject;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList();
                      },
                      items: availableSchedules
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.subject.isNotEmpty
                                          ? s.subject
                                          : s.examName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  if (s.examDate.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        s.examDate,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedSchedule = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Exam Preview Summary Card
            if (selectedSchedule != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.school_outlined,
                            size: 22,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${selectedSchedule!.examName} • ${selectedSchedule!.subject}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Class ${selectedClass?.standard ?? selectedSchedule!.standard ?? ''} • Section ${selectedSchedule!.section}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Text(
                            'Published',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            label: 'Max Marks',
                            value: selectedSchedule!.maximumMarks.toString(),
                            icon: Icons.star_outline_rounded,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            label: 'Passing Marks',
                            value: selectedSchedule!.passingMarks.toString(),
                            icon: Icons.check_circle_outline_rounded,
                            color: const Color(0xFFB91C1C),
                          ),
                        ),
                        if (selectedSchedule!.examDate.isNotEmpty)
                          Expanded(
                            child: _buildInfoItem(
                              label: 'Exam Date',
                              value: selectedSchedule!.examDate,
                              icon: Icons.event_outlined,
                              color: const Color(0xFF334155),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 36,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Select an exam to get started',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose Exam Name, Class, and Section above.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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

  Widget _buildInfoItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
