import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:provider/provider.dart';

import '../../dialogs/attendance_mode_dialog.dart';
import '../../models/assigned_entities.dart';
import '../../models/create_attendance.dart';
import '../../models/student.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/students_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/hive_service.dart';
import '../../services/injectable.dart';
import '../../utils/app_utils.dart';
import 'attendance_confirmation_page.dart';

class SdkAttendancePage extends StatefulWidget {
  const SdkAttendancePage({
    super.key,
    required this.standard,
    required this.section,
    required this.initialMode,
  });

  final AssignedEntityClass standard;
  final String section;
  final AttendanceModeOption initialMode;

  @override
  State<SdkAttendancePage> createState() => _SdkAttendancePageState();
}

class _SdkAttendancePageState extends State<SdkAttendancePage> {
  late final IcueFaceSdk _sdk;
  bool _initializing = true;
  bool _loadingStudents = true;
  bool _cameraBusy = false;
  String? _errorMessage;
  List<StudentData> _studentList = [];
  AttendanceResult? _lastAttendanceResult;

  @override
  void initState() {
    super.initState();
    _sdk = IcueFaceSdk();
    getIt<AnalyticsService>().logScreenView(
      screenName: 'sdk-attendance-page',
      parameters: {
        'standard': widget.standard.standard,
        'section': widget.section,
      },
    );
    _initSdkAndFetchStudents();
  }

  Future<void> _initSdkAndFetchStudents() async {
    try {
      await _sdk.initialize();
      if (!mounted) return;

      final studentsProvider = context.read<StudentsProvider>();
      await studentsProvider.getStudents(
        context,
        widget.standard.classId,
        [widget.section],
        forAttendance: true,
        pageNo: 1,
      );

      if (!mounted) return;
      _studentList = studentsProvider.attendanceStudents;

      if (_studentList.isNotEmpty) {
        final studentIds = _studentList.map((e) => e.id).toList();
        await studentsProvider.getStudentEmbeddings(studentIds: studentIds);
      }

      if (!mounted) return;

      if (widget.initialMode == AttendanceModeOption.sdkLive) {
        await _startLiveAttendance(autoLaunch: true);
      } else if (widget.initialMode == AttendanceModeOption.sdkPhoto) {
        await _startMultiPhotoAttendance(autoLaunch: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to initialize Face Recognition: $e';
        _initializing = false;
        _loadingStudents = false;
      });
    }
  }

  List<FaceProfile> _buildRoster() {
    final studentsProvider = context.read<StudentsProvider>();
    final roster = <FaceProfile>[];
    for (final student in _studentList) {
      final embedding = studentsProvider.studentEmbeddings[student.id];
      if (embedding != null &&
          embedding.length == faceEmbeddingSize &&
          embedding.every((e) => e.isFinite)) {
        roster.add(
          FaceProfile(personId: student.id.toString(), embedding: embedding),
        );
      }
    }
    return roster;
  }

  Future<void> _startLiveAttendance({bool autoLaunch = false}) async {
    if (_cameraBusy || _studentList.isEmpty) return;
    final roster = _buildRoster();
    if (roster.isEmpty) {
      if (!autoLaunch && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No registered face profiles found for this class. Please register face profiles first.',
            ),
          ),
        );
      }
      setState(() {
        _initializing = false;
        _loadingStudents = false;
      });
      return;
    }
    setState(() {
      _cameraBusy = true;
      if (!autoLaunch) {
        _initializing = true;
      }
    });

    try {
      final result = await _sdk.startLiveAttendance(
        roster: roster,
        config: const AttendanceConfig(
          showMatchingPercentage: false,
          showDetectedLabel: false,
          showUnrecognizedLabel: false,
          // autoFinishWhenComplete: true,
        ),
      );
      if (!mounted) return;

      if (result != null) {
        setState(() => _lastAttendanceResult = result);
        await _applyAttendanceResult(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error running live attendance: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cameraBusy = false;
          _initializing = false;
          _loadingStudents = false;
        });
      }
    }
  }

  Future<void> _startMultiPhotoAttendance({bool autoLaunch = false}) async {
    if (_cameraBusy || _studentList.isEmpty) return;
    final roster = _buildRoster();
    if (roster.isEmpty) {
      if (!autoLaunch && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No registered face profiles found for this class. Please register face profiles first.',
            ),
          ),
        );
      }
      setState(() {
        _initializing = false;
        _loadingStudents = false;
      });
      return;
    }
    setState(() {
      _cameraBusy = true;
      if (!autoLaunch) {
        _initializing = true;
      }
    });

    try {
      final result = await _sdk.startMultiPhotoAttendance(
        roster: roster,
        config: const AttendanceConfig(
          // Customize your configurations:
          // showMatchingPercentage: false,
          // showDetectedLabel: false,
          // showUnrecognizedLabel: false,
          unrecognizedLabel:
              'UNKNOWN FACE', // default is 'UNREGISTERED STUDENT'
        ),
      );
      if (!mounted) return;

      if (result != null) {
        setState(() => _lastAttendanceResult = result);
        await _applyAttendanceResult(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error running photo attendance: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cameraBusy = false;
          _initializing = false;
          _loadingStudents = false;
        });
      }
    }
  }

  Future<void> _applyAttendanceResult(AttendanceResult result) async {
    if (!mounted) return;
    AppUtils.showLoadingDialog(context, 'Saving attendance... Please wait...');

    try {
      final attendanceProvider = context.read<AttendanceProvider>();
      final key = attendanceProvider.effectiveAttendanceKey;
      final existingAttendance = key != null
          ? HiveService.createAttendanceBox.get(key)
          : null;
      final existingPresentIds =
          existingAttendance?.students
              .where((s) => s.isPresent)
              .map((s) => s.id)
              .toSet() ??
          <int>{};

      final newlyPresentIds = result.present.map((e) => e.personId).toSet();

      final isLiveMode =
          widget.initialMode == AttendanceModeOption.sdkLive ||
          result.mode == AttendanceMode.liveStream;

      final studentsToUpdate = _studentList.map((student) {
        final isPresent =
            existingPresentIds.contains(student.id) ||
            newlyPresentIds.contains(student.id.toString());
        return AttendanceStudent(
          id: student.id,
          name: student.name,
          rollNo: student.rollNo,
          admissionNumber: student.admissionNumber,
          isPresent: isPresent,
          uid: student.uid,
          attendanceMode: 'FACIAL',
        );
      }).toList();

      await attendanceProvider.updateAttendanceBulk(
        classId: widget.standard.classId,
        className: widget.standard.standard,
        section: widget.section,
        period: '',
        students: studentsToUpdate,
        attendanceMode: isLiveMode ? 'FACIAL_LIVE' : 'FACIAL_PHOTO',
        images: isLiveMode ? null : result.capturedImagePaths,
      );

      if (!mounted) return;
      AppUtils.hideLoadingDialog(context);
      final res = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const AttendanceConfirmationPage(),
        ),
      );
      if (res == 'ADD_MORE' && mounted) {
        if (widget.initialMode == AttendanceModeOption.sdkLive) {
          _startLiveAttendance();
        } else {
          _startMultiPhotoAttendance();
        }
      } else if (res == 'DISCARD' && mounted) {
        setState(() {
          _lastAttendanceResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        AppUtils.hideLoadingDialog(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving attendance: $e')));
      }
    }
  }

  @override
  void dispose() {
    _sdk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentsProvider = context.watch<StudentsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '${widget.standard.standard} - Section ${widget.section}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _initializing || _loadingStudents
          ? _buildLoadingState(theme)
          : _errorMessage != null
          ? _buildErrorState()
          : _buildMainContent(theme, studentsProvider),
      floatingActionButton:
          _initializing || _loadingStudents || _errorMessage != null
          ? null
          : FloatingActionButton.extended(
              onPressed: (_cameraBusy || _studentList.isEmpty)
                  ? null
                  : () {
                      if (widget.initialMode == AttendanceModeOption.sdkLive) {
                        _startLiveAttendance();
                      } else {
                        _startMultiPhotoAttendance();
                      }
                    },
              label: Text(
                widget.initialMode == AttendanceModeOption.sdkLive
                    ? 'Start Live Scan'
                    : 'Start Group Scan',
              ),
              icon: Icon(
                widget.initialMode == AttendanceModeOption.sdkLive
                    ? Icons.videocam_rounded
                    : Icons.groups_rounded,
              ),
            ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Initializing Face Recognition Engine',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Loading class roster...',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Initialization Failed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _initializing = true;
                  _loadingStudents = true;
                  _errorMessage = null;
                });
                _initSdkAndFetchStudents();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme, StudentsProvider studentsProvider) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        if (_lastAttendanceResult != null) ...[
          _buildResultBanner(theme),
          const SizedBox(height: 20),
        ],
        _buildRosterSection(theme, studentsProvider),
      ],
    );
  }

  Widget _buildResultBanner(ThemeData theme) {
    final result = _lastAttendanceResult!;
    final presentCount = result.present.length;
    final totalCount = result.totalRosterCount;
    final percentage = totalCount > 0
        ? ((presentCount / totalCount) * 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Last Scan Result',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percentage% Present',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$presentCount out of $totalCount students marked present.',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF047857),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final res = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AttendanceConfirmationPage(),
                  ),
                );
                if (res == 'ADD_MORE' && mounted) {
                  if (widget.initialMode == AttendanceModeOption.sdkLive) {
                    _startLiveAttendance();
                  } else {
                    _startMultiPhotoAttendance();
                  }
                } else if (res == 'DISCARD' && mounted) {
                  setState(() {
                    _lastAttendanceResult = null;
                  });
                }
              },
              icon: const Icon(Icons.rate_review_rounded, size: 18),
              label: const Text(
                'PROCEED TO CONFIRMATION',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterSection(
    ThemeData theme,
    StudentsProvider studentsProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Class Roster Preview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Text(
              '${_studentList.length} total',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_studentList.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                'No students found in this section.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _studentList.length > 5 ? 5 : _studentList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final student = _studentList[index];
              final hasEmbedding = studentsProvider.studentEmbeddings
                  .containsKey(student.id);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        student.name.isNotEmpty
                            ? student.name[0].toUpperCase()
                            : 'S',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Roll #${student.rollNo}  •  Adm: ${student.admissionNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: hasEmbedding
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasEmbedding ? 'Face Registered' : 'No Face Info',
                        style: TextStyle(
                          color: hasEmbedding
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        if (_studentList.length > 5) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              '+ ${_studentList.length - 5} more students in roster',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
