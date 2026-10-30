import 'package:attendance/attendance.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';

class SdkAttendancePage extends StatefulWidget {
  const SdkAttendancePage({
    required this.standard,
    required this.section,
    required this.initialMode,
    super.key,
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
  bool _cameraBusy = false;
  String? _errorMessage;
  List<StudentData> _studentList = [];

  @override
  void initState() {
    super.initState();
    _sdk = IcueFaceSdk();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSdkAndFetch());
  }

  Future<void> _initSdkAndFetch() async {
    try {
      await _sdk.initialize();
      if (!mounted) return;

      final routesProvider = context.read<RoutesProvider>();
      await routesProvider.fetchStudents(widget.standard.classId, [
        widget.section,
      ]);

      if (!mounted) return;
      _studentList = routesProvider.students;

      if (_studentList.isNotEmpty) {
        final auth = context.read<AuthProvider>();
        final user = auth.user;
        if (user != null) {
          final branchId = auth.selectedBranch?.id ?? user.branchId;
          final studentIds = _studentList.map((e) => e.id).toList();

          await context.read<AttendanceProvider>().fetchStudentEmbeddings(
            organizationId: user.organizationId,
            zoneId: user.zoneId,
            branchId: branchId,
            studentIds: studentIds,
          );
        }
      }

      if (!mounted) return;

      if (widget.initialMode == AttendanceModeOption.sdkLive) {
        await _startLiveAttendance(autoLaunch: true);
      } else {
        await _startMultiPhotoAttendance(autoLaunch: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to initialize Face Recognition: $e';
        _initializing = false;
      });
    }
  }

  List<FaceProfile> _buildRoster() {
    final attendanceProvider = context.read<AttendanceProvider>();
    final embeddings = attendanceProvider.studentEmbeddings;
    final roster = <FaceProfile>[];

    for (final student in _studentList) {
      final embedding = embeddings[student.id];
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
      setState(() => _initializing = false);
      return;
    }

    setState(() {
      _cameraBusy = true;
      if (!autoLaunch) _initializing = true;
    });

    try {
      final result = await _sdk.startLiveAttendance(
        roster: roster,
        config: const AttendanceConfig(
          showMatchingPercentage: false,
          showDetectedLabel: false,
          showUnrecognizedLabel: false,
        ),
      );

      if (!mounted) return;
      if (result != null) {
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
      setState(() => _initializing = false);
      return;
    }

    setState(() {
      _cameraBusy = true;
      if (!autoLaunch) _initializing = true;
    });

    try {
      final result = await _sdk.startMultiPhotoAttendance(
        roster: roster,
        config: const AttendanceConfig(unrecognizedLabel: 'UNKNOWN FACE'),
      );

      if (!mounted) return;
      if (result != null) {
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
        });
      }
    }
  }

  Future<void> _applyAttendanceResult(AttendanceResult result) async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final ongoing = attendanceProvider.ongoingAttendance;
    final previouslyPresent =
        ongoing?.students.where((s) => s.isPresent).map((s) => s.id).toSet() ??
        <int>{};

    final recognizedIds = result.present.map((e) => e.personId).toSet();

    final isLive =
        widget.initialMode == AttendanceModeOption.sdkLive ||
        result.mode == AttendanceMode.liveStream;

    final updatedStudents = _studentList.map((student) {
      final isPresent =
          previouslyPresent.contains(student.id) ||
          recognizedIds.contains(student.id.toString());
      return AttendanceStudent(
        id: student.id,
        name: student.name,
        rollNo: student.rollNo,
        admissionNumber: student.admissionNumber,
        isPresent: isPresent,
        attendanceMode: 'FACIAL',
      );
    }).toList();

    await attendanceProvider.updateAttendanceBulk(
      classId: widget.standard.classId,
      className: widget.standard.standard,
      section: widget.section,
      period: '',
      students: updatedStudents,
      attendanceMode: isLive ? 'FACIAL_LIVE' : 'FACIAL_PHOTO',
      images: isLive ? null : result.capturedImagePaths,
    );

    if (!mounted) return;
    await context.push(AppRoutes.attendanceConfirmation);
  }

  @override
  Widget build(BuildContext context) {
    final rosterCount = _buildRoster().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialMode == AttendanceModeOption.sdkLive
              ? 'Live Face Scan'
              : 'Multi-Photo Scan',
        ),
      ),
      body: _initializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing Face Engine & Roster...'),
                ],
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _initSdkAndFetch,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.initialMode == AttendanceModeOption.sdkLive
                            ? Icons.videocam_rounded
                            : Icons.camera_alt_rounded,
                        size: 64,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${widget.standard.standard} - Section ${widget.section}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$rosterCount registered face profiles ready for match.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _cameraBusy
                          ? null
                          : () {
                              if (widget.initialMode ==
                                  AttendanceModeOption.sdkLive) {
                                _startLiveAttendance();
                              } else {
                                _startMultiPhotoAttendance();
                              }
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(Icons.camera),
                      label: const Text('Open Camera Scanner'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
