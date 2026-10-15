import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/students_provider.dart';
import '../../utils/app_utils.dart';
import 'class_results_page.dart';
import 'exam_helpers.dart';

class ExamResultsPage extends StatefulWidget {
  const ExamResultsPage({super.key});

  @override
  State<ExamResultsPage> createState() => _ExamResultsPageState();
}

class _ExamResultsPageState extends State<ExamResultsPage> {
  String selectedAcademicYear = ExamHelpers.getCurrentAcademicYear();
  String? selectedExamName;
  ExamClassOption? selectedClass;
  String? selectedSection;
  int? selectedStudentId; // null means 'All students'
  String? selectedStudentName;
  bool _generating = false;

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
  }

  void _loadStudentsForClass(int classId, String section) {
    final studentsProvider = context.read<StudentsProvider>();
    studentsProvider.getStudents(context, classId, [section], pageNo: 1);
  }

  Future<void> _onGenerateResults() async {
    if (selectedClass == null || selectedSection == null) {
      AppUtils.showErrorMessage(
        context,
        'Please select a Class and Section to view results',
      );
      return;
    }

    if (selectedExamName == null || selectedExamName!.trim().isEmpty) {
      AppUtils.showErrorMessage(
        context,
        'Please select an Exam Name to view results',
      );
      return;
    }

    setState(() => _generating = true);
    final examProvider = context.read<ExamProvider>();

    try {
      final results = await examProvider.getExamResults(
        academicYear: selectedAcademicYear,
        examName: selectedExamName!,
        classId: selectedClass!.classId,
        section: selectedSection!,
      );

      if (!mounted) return;

      if (results.isEmpty) {
        AppUtils.showErrorMessage(
          context,
          'No results found for ${selectedClass!.standard} Section $selectedSection',
        );
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClassResultsPage(
            academicYear: selectedAcademicYear,
            examName: selectedExamName!,
            classOption: selectedClass!,
            section: selectedSection!,
            initialStudentId: selectedStudentId,
            initialStudentName: selectedStudentName,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _generating = false);
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

  @override
  Widget build(BuildContext context) {
    final examProvider = context.watch<ExamProvider>();
    final studentsProvider = context.watch<StudentsProvider>();
    context.watch<AuthProvider>();
    final classes = ExamHelpers.getAvailableClasses(context);

    // Fallback if user has no assigned classes in userInfo
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

    // Available Exam Names from getPrepExams
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

    // Section options
    final List<String> sectionOptions = matchingClass?.sections ?? [];
    final effectiveSection =
        (selectedSection != null && sectionOptions.contains(selectedSection))
        ? selectedSection
        : null;

    // Students for selected class & section
    final List<StudentData> classStudents = studentsProvider.students;
    final isCanGenerate =
        matchingClass != null &&
        effectiveSection != null &&
        selectedExamName != null &&
        selectedExamName!.isNotEmpty;

    // Button color matching Web UI (dark emerald / teal)
    const generateBtnColor = Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Class Results',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
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
              backgroundColor: generateBtnColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: (isCanGenerate && !_generating && !examProvider.loading)
                ? _onGenerateResults
                : null,
            child: _generating || examProvider.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assessment_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Generate Results',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                              color: generateBtnColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              size: 20,
                              color: generateBtnColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Results Configuration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'Select exam criteria to generate class results',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (examProvider.loading ||
                              studentsProvider.studentsLoading)
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

                      // 1. Academic Year & Exam Name Row
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
                                });
                                examProvider.getPrepExams(selectedAcademicYear);
                              }
                            },
                          );

                          final examNameField = _buildDropdownField<String>(
                            label: 'Exam Name',
                            value: allExamNames.contains(selectedExamName)
                                ? selectedExamName
                                : null,
                            hint: allExamNames.isEmpty
                                ? 'No exams found'
                                : 'Select exam',
                            isEnabled: allExamNames.isNotEmpty,
                            selectedItemBuilder: (context) {
                              return allExamNames.map((name) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            items: allExamNames.map((name) {
                              final isSelected = name == selectedExamName;
                              return DropdownMenuItem(
                                value: name,
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
                                    Expanded(
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => selectedExamName = val);
                            },
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                academicYearField,
                                const SizedBox(height: 14),
                                examNameField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: academicYearField),
                              const SizedBox(width: 14),
                              Expanded(child: examNameField),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 14),

                      // 2. Class / Standard & Section Row
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 600;

                          final classField =
                              _buildDropdownField<ExamClassOption>(
                                label: 'Class / Standard',
                                value: matchingClass,
                                hint: classes.isEmpty
                                    ? 'No classes found'
                                    : 'Select class',
                                isEnabled: classes.isNotEmpty,
                                selectedItemBuilder: (context) {
                                  return classes.map((c) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        c.standard,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    );
                                  }).toList();
                                },
                                items: classes.map((c) {
                                  final isSelected =
                                      c.classId == matchingClass?.classId;
                                  return DropdownMenuItem(
                                    value: c,
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
                                          c.standard,
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
                                  if (val != null) {
                                    setState(() {
                                      selectedClass = val;
                                      selectedSection = null;
                                      selectedStudentId = null;
                                      selectedStudentName = null;
                                    });
                                  }
                                },
                              );

                          final sectionField = _buildDropdownField<String>(
                            label: 'Section',
                            value: effectiveSection,
                            hint: sectionOptions.isEmpty
                                ? 'No sections'
                                : 'Select section',
                            isEnabled: sectionOptions.isNotEmpty,
                            selectedItemBuilder: (context) {
                              return sectionOptions.map((sec) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Section $sec',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            items: sectionOptions.map((sec) {
                              final isSelected = sec == effectiveSection;
                              return DropdownMenuItem(
                                value: sec,
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
                                      'Section $sec',
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
                              if (val != null) {
                                setState(() {
                                  selectedSection = val;
                                  selectedStudentId = null;
                                  selectedStudentName = null;
                                });
                                if (matchingClass != null) {
                                  _loadStudentsForClass(
                                    matchingClass.classId,
                                    val,
                                  );
                                }
                              }
                            },
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                classField,
                                const SizedBox(height: 14),
                                sectionField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: classField),
                              const SizedBox(width: 14),
                              Expanded(child: sectionField),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 14),

                      // 3. Student Filter Dropdown (matching Web UI)
                      _buildDropdownField<int?>(
                        label: 'Student',
                        value: selectedStudentId,
                        hint: 'All students',
                        selectedItemBuilder: (context) {
                          final items = <int?, String>{null: 'All students'};
                          for (final s in classStudents) {
                            items[s.id] = s.name;
                          }
                          return items.entries.map((e) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                e.value,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            );
                          }).toList();
                        },
                        items: [
                          const DropdownMenuItem<int?>(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people_alt_outlined,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'All students',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...classStudents.map((s) {
                            final isSelected = s.id == selectedStudentId;
                            final roll = s.rollNo.isNotEmpty
                                ? ' (Roll: ${s.rollNo})'
                                : '';
                            return DropdownMenuItem<int?>(
                              value: s.id,
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
                                  Expanded(
                                    child: Text(
                                      '${s.name}$roll',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            selectedStudentId = val;
                            if (val != null) {
                              final match = classStudents.firstWhereOrNull(
                                (s) => s.id == val,
                              );
                              selectedStudentName = match?.name;
                            } else {
                              selectedStudentName = null;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Instructional tip / summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isCanGenerate
                            ? 'Ready to generate results for ${matchingClass.standard} Sec $effectiveSection (${selectedExamName!}).'
                            : 'Please select an Exam Name, Class, and Section to generate class results.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
