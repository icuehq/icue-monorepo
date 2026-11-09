import 'dart:async';

import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/providers/student_provider.dart';
import 'package:face_enrollment/src/ui/face_enrollment_routes.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:face_enrollment/src/ui/widgets/ambient_background.dart';
import 'package:face_enrollment/src/ui/widgets/batch_action_dock.dart';
import 'package:face_enrollment/src/ui/widgets/directory_dialogs.dart';
import 'package:face_enrollment/src/ui/widgets/student_card.dart';
import 'package:face_enrollment/src/ui/widgets/student_directory_header.dart';
import 'package:face_enrollment/src/ui/widgets/student_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<StudentProvider>(context, listen: false);
      await provider.fetchStandards();
      unawaited(provider.resetAndFetch());
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      Provider.of<StudentProvider>(context, listen: false).fetchStudents();
    }
  }

  Future<void> _handleLogout() => context.read<AuthProvider>().logout();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final studentProvider = Provider.of<StudentProvider>(context);

    return Scaffold(
      backgroundColor: context.scheme.surface,
      appBar: StudentDirectoryAppBar(
        userName: authProvider.user?.name ?? 'Administrator',
        onIdentify: () => context.push(FaceEnrollmentRoutes.identify),
        onSync: () => handleSyncEmbeddings(context, studentProvider),
        onLogout: () => confirmLogout(context, _handleLogout),
      ),
      body: AmbientBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 6),
              // Filter & Search Hub
              StudentFilterBar(
                studentProvider: studentProvider,
                searchController: _searchController,
              ),

              // Student Directory List Content
              Expanded(child: _buildListContent(studentProvider)),

              // AI Batch Enrollment Dock
              BatchActionDock(studentProvider: studentProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListContent(StudentProvider studentProvider) {
    if (studentProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'LOADING STUDENT DIRECTORY...',
              style: TextStyle(
                color: context.scheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (studentProvider.errorMessage != null &&
        studentProvider.students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: context.scheme.error,
              ),
              const SizedBox(height: 14),
              Text(
                studentProvider.errorMessage!,
                style: TextStyle(color: context.scheme.onSurface, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 150,
                child: AppButton(
                  label: 'Try Again',
                  onPressed: () => studentProvider.resetAndFetch(),
                  isFullWidth: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (studentProvider.classId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 56,
                color: context.scheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'Select a Class',
                style: TextStyle(
                  color: context.scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please select a class from the dropdown above to view students.',
                style: TextStyle(
                  color: context.scheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final List<Student> studentList = studentProvider.filteredStudents;
    if (studentList.isEmpty) {
      if (studentProvider.searchQuery.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 52,
                  color: context.scheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Students Found',
                  style: TextStyle(
                    color: context.scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'No match for "${studentProvider.searchQuery}". Try a different name or ID.',
                  style: TextStyle(
                    color: context.scheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 140,
                  child: AppButton(
                    label: 'Clear Search',
                    variant: AppButtonVariant.outline,
                    onPressed: () {
                      _searchController.clear();
                      studentProvider.updateSearchQuery('');
                    },
                    isFullWidth: true,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_off_rounded,
                size: 52,
                color: context.scheme.onSurface.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 12),
              Text(
                studentProvider.studentPhotoFilter == true
                    ? 'No students with photos in this class.'
                    : (studentProvider.studentPhotoFilter == false
                          ? 'All students in this class have photos!'
                          : 'No students found in this class.'),
                style: TextStyle(
                  color: context.scheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 140,
                child: AppButton(
                  label: 'Refresh',
                  variant: AppButtonVariant.outline,
                  onPressed: () => studentProvider.resetAndFetch(),
                  isFullWidth: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: context.scheme.primary,
      backgroundColor: Colors.white,
      onRefresh: studentProvider.resetAndFetch,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: studentList.length + (studentProvider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == studentList.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.scheme.primary,
                    ),
                  ),
                ),
              ),
            );
          }

          final student = studentList[index];
          final isEnrolled = studentProvider.hasEmbedding(student.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: StudentCard(
              student: student,
              isEnrolled: isEnrolled,
              onTapFingerprint: () async {
                await context.push(
                  FaceEnrollmentRoutes.embedding,
                  extra: student,
                );
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          );
        },
      ),
    );
  }
}
