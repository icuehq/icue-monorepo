import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/student_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../widgets/ambient_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_dropdown_field.dart';
import '../widgets/glass_card.dart';
import '../widgets/student_card.dart';
import 'embedding_screen.dart';
import 'identify_screen.dart';
import 'login_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<StudentProvider>(context, listen: false);
      await provider.fetchStandards();
      if (!mounted) return;
      provider.resetAndFetch();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      Provider.of<StudentProvider>(context, listen: false).fetchStudents();
    }
  }

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final studentProvider = Provider.of<StudentProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Futuristic Top Navigation Header
              _buildTopHeader(context, authProvider, studentProvider),

              // Control Center
              _buildControlCenter(studentProvider),

              // Main Directory Student List
              Expanded(child: _buildListContent(studentProvider)),

              // Glassmorphic Floating Cyber Batch Action Dock
              _buildFloatingCyberDock(context, studentProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    AuthProvider authProvider,
    StudentProvider studentProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 18,
        bgColor: const Color(0x1AFFFFFF),
        bordercolor: const Color(0x336C63FF),
        child: Row(
          children: [
            // Title & User Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00E5FF),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'STUDENT DIRECTORY',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF8C85FF),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          authProvider.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Action Icons
            _buildHeaderActionButton(
              icon: Icons.camera_front_rounded,
              tooltip: 'Identify Student',
              color: const Color(0xFF00E5FF),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const IdentifyScreen(),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            _buildHeaderActionButton(
              icon: Icons.sync_rounded,
              tooltip: 'Sync Embeddings',
              color: const Color(0xFF6C63FF),
              onPressed: () => _handleSyncEmbeddings(context, studentProvider),
            ),
            const SizedBox(width: 4),
            _buildHeaderActionButton(
              icon: Icons.power_settings_new_rounded,
              tooltip: 'Logout',
              color: const Color(0xFFFF2A54),
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }

  Widget _buildControlCenter(StudentProvider studentProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.all(1),
        borderRadius: 15,
        bgColor: const Color(0x12FFFFFF),
        bordercolor: Colors.white.withValues(alpha: 0.12),
        child: CustomDropdownField<int>(
          value:
              studentProvider.standards.any(
                (s) => s.id == studentProvider.classId,
              )
              ? studentProvider.classId
              : null,
          borderRadius: 12,
          items: studentProvider.standards.map((std) {
            return DropdownMenuItem<int>(value: std.id, child: Text(std.name));
          }).toList(),
          onChanged: (newClassId) {
            if (newClassId != null) {
              studentProvider.setClassId(newClassId);
            }
          },
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
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'LOADING STUDENT DIRECTORY...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
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
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Color(0xFFFF2A54),
              ),
              const SizedBox(height: 16),
              Text(
                studentProvider.errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                child: CustomButton(
                  text: 'Try Again',
                  height: 44,
                  borderRadius: 14,
                  onPressed: () async {
                    if (studentProvider.standards.isEmpty) {
                      await studentProvider.fetchStandards();
                    }
                    studentProvider.resetAndFetch();
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    final list = studentProvider.filteredStudents;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No students found in this class.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF15102A),
      onRefresh: studentProvider.resetAndFetch,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length + (studentProvider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == list.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C63FF),
                    ),
                  ),
                ),
              ),
            );
          }

          final student = list[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: StudentCard(
              student: student,
              onTapFingerprint: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        EmbeddingScreen(student: student),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOutCubic;
                          var tween = Tween(
                            begin: begin,
                            end: end,
                          ).chain(CurveTween(curve: curve));
                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingCyberDock(
    BuildContext context,
    StudentProvider studentProvider,
  ) {
    final studentsWithImages = studentProvider.filteredStudents
        .where((s) => s.photoUrl != null && s.photoUrl!.isNotEmpty)
        .take(10)
        .toList();

    if (studentsWithImages.isEmpty || studentProvider.isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        borderRadius: 20,
        bgColor: const Color(0x286C63FF),
        bordercolor: const Color(0xFF6C63FF).withValues(alpha: 0.5),
        child: Row(
          children: [
            const Icon(
              Icons.psychology_rounded,
              color: Color(0xFF00E5FF),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'AI BATCH EMBEDDINGS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${studentsWithImages.length} candidates ready for processing',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _showBatchProgressDialog(
                context,
                studentProvider,
                studentsWithImages,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: Color(0xFF00E5FF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'GENERATE (${studentsWithImages.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF15102A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.power_settings_new_rounded,
                size: 48,
                color: Color(0xFFFF2A54),
              ),
              const SizedBox(height: 12),
              const Text(
                'Confirm Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to exit your administrative session?',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleLogout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2A54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSyncEmbeddings(
    BuildContext context,
    StudentProvider studentProvider,
  ) {
    final syncFuture = studentProvider.syncEmbeddingsFromServer();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return FutureBuilder<int>(
          future: syncFuture,
          builder: (context, snapshot) {
            final isProcessing =
                snapshot.connectionState == ConnectionState.waiting;
            final hasError = snapshot.hasError;
            final data = snapshot.data;

            return Dialog(
              backgroundColor: const Color(0xFF15102A),
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
                              ? Icons.sync_rounded
                              : hasError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          color: isProcessing
                              ? const Color(0xFF6C63FF)
                              : hasError
                              ? const Color(0xFFFF2A54)
                              : const Color(0xFF00E676),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isProcessing
                                ? 'Syncing Embeddings...'
                                : hasError
                                ? 'Sync Failed'
                                : 'Sync Completed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (isProcessing) ...[
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Downloading face embeddings from the server and updating local storage cache...',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ] else if (hasError) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2A54).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFFF2A54,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          snapshot.error.toString().replaceAll(
                            'Exception: ',
                            '',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFFF2A54),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryStat(
                              label: 'Synced',
                              value: data.toString(),
                              color: const Color(0xFF00E676),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'All synchronized embeddings are stored in local preferences and ready for scanning.',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isProcessing)
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
        );
      },
    );
  }

  void _showBatchProgressDialog(
    BuildContext context,
    StudentProvider studentProvider,
    List<Student> targetStudents,
  ) {
    studentProvider.generateAndUploadBatchEmbeddings(targetStudents);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: Consumer<StudentProvider>(
            builder: (context, provider, child) {
              final isProcessing = provider.isBatchProcessing;
              final progress = provider.batchProgress;
              final message = provider.batchProgressMessage;
              final successCount = provider.batchSuccessCount;
              final failureCount = provider.batchFailureCount;
              final totalCount = provider.batchTotalCount;

              return Dialog(
                backgroundColor: const Color(0xFF15102A),
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
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFF00E676),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isProcessing
                                  ? 'Generating Embeddings...'
                                  : 'Batch Process Completed',
                              style: const TextStyle(
                                color: Colors.white,
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
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF6C63FF),
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
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${successCount + failureCount} / $totalCount',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryStat(
                                label: 'Total',
                                value: totalCount.toString(),
                                color: Colors.white70,
                              ),
                              _buildSummaryStat(
                                label: 'Success',
                                value: successCount.toString(),
                                color: const Color(0xFF00E676),
                              ),
                              _buildSummaryStat(
                                label: 'Failed',
                                value: failureCount.toString(),
                                color: const Color(0xFFFF2A54),
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
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: isProcessing ? Colors.white70 : Colors.white,
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
                              onPressed: provider.cancelBatchRequested
                                  ? null
                                  : () => provider.cancelBatchProcessing(),
                              icon: const Icon(Icons.cancel_rounded, size: 18),
                              label: const Text('Cancel'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFF2A54),
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
                                  provider.resetAndFetch();
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

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
