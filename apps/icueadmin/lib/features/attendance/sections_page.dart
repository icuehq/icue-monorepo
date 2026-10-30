import 'package:attendance/attendance.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/attendance/widgets/attendance_mode_sheet.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SectionsPage extends StatefulWidget {
  const SectionsPage({required this.standard, super.key});

  final AssignedEntityClass standard;

  @override
  State<SectionsPage> createState() => _SectionsPageState();
}

class _SectionsPageState extends State<SectionsPage> {
  String? _selectedSection;
  bool _isChecking = false;

  Future<void> _handleSectionSelected(String sectionName) async {
    setState(() => _isChecking = true);

    try {
      final attendanceProvider = context.read<AttendanceProvider>();
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final exists = await attendanceProvider.checkAttendanceExists(
        classId: widget.standard.classId,
        section: sectionName,
        date: date,
        period: '1',
      );

      if (!mounted) return;

      if (exists) {
        setState(() => _selectedSection = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attendance has already been submitted for ${widget.standard.standard} - Section $sectionName.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        setState(() => _selectedSection = sectionName);
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _handleStartAttendance() async {
    if (_selectedSection == null) return;

    final mode = await AttendanceModeSheet.show(context);
    if (mode == null || !mounted) return;

    if (mode == AttendanceModeOption.manual) {
      await context.push(
        AppRoutes.createAttendance,
        extra: {
          'standard': widget.standard,
          'section': _selectedSection!,
        },
      );
    } else {
      await context.push(
        AppRoutes.sdkAttendance,
        extra: {
          'standard': widget.standard,
          'section': _selectedSection!,
          'initialMode': mode,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('${widget.standard.standard} Sections'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed:
                _selectedSection == null || _isChecking ? null : _handleStartAttendance,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Start Attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : widget.standard.sections.isEmpty
              ? Center(
                  child: Text(
                    'No sections available for this class.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : RadioGroup<String>(
                  groupValue: _selectedSection,
                  onChanged: (val) {
                    if (val != null) _handleSectionSelected(val);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.standard.sections.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final section = widget.standard.sections[index];
                      final isSelected = section == _selectedSection;

                      return Card(
                        elevation: isSelected ? 2 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          title: Text(
                            'Section $section',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.bookmark_outline,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          value: section,
                          activeColor: theme.colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
