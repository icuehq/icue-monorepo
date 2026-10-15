import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/di/injection.dart';
import '../../core/storage/pref_service.dart';
import '../../data/models/student_model.dart';
import '../../providers/identify_provider.dart';
import '../../providers/student_provider.dart';
import '../widgets/ambient_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/unrecognized_student_dialog.dart';

class IdentifyScreen extends StatefulWidget {
  const IdentifyScreen({super.key});

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen> {
  late IcueFaceSdk _faceSdk;

  bool _isPreparing = true;
  bool _isScanning = false;
  String _statusText = 'Initializing Face Recognition Engine...';
  double _prepProgress = 0.0;

  AttendanceType _attendanceType = AttendanceType.TRANSPORT;
  DetectedLabelField _detectedLabelField = DetectedLabelField.ID;
  double _labelFontSize = 12.0;

  bool _isAlertShowing = false;

  final List<FaceProfile> _faceProfiles = [];
  final Map<String, Student> _candidateStudentMap = {};

  AttendanceResult? _lastAttendanceResult;
  List<Student> _identifiedStudents = [];

  @override
  void initState() {
    super.initState();
    _faceSdk = getIt<IcueFaceSdk>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndLoadRoster();
    });
  }

  Future<void> _initAndLoadRoster() async {
    try {
      setState(() {
        _isPreparing = true;
        _statusText = 'Initializing Face Recognition Engine...';
        _prepProgress = 0.2;
      });

      await _faceSdk.initialize();

      if (!mounted) return;

      final studentProvider = Provider.of<StudentProvider>(
        context,
        listen: false,
      );
      final prefService = getIt<PrefService>();
      final candidates = studentProvider.filteredStudents.isNotEmpty
          ? studentProvider.filteredStudents
          : studentProvider.students;

      _faceProfiles.clear();
      _candidateStudentMap.clear();

      for (int i = 0; i < candidates.length; i++) {
        final student = candidates[i];
        if (prefService.hasStudentEmbedding(student.id)) {
          final savedEmbedding = prefService.getStudentEmbedding(student.id);
          if (savedEmbedding != null &&
              savedEmbedding.embedding.length == faceEmbeddingSize &&
              savedEmbedding.embedding.every((e) => e.isFinite)) {
            _candidateStudentMap[student.id.toString()] = student;
            _faceProfiles.add(
              FaceProfile(
                personId: student.id.toString(),
                embedding: savedEmbedding.embedding,
                name: student.name,
                label: student.admissionNumber,
              ),
            );
          }
        }
        if (mounted) {
          setState(() {
            _prepProgress = 0.2 + (0.8 * (i + 1) / candidates.length);
          });
        }
      }

      if (!mounted) return;

      setState(() {
        _isPreparing = false;
        if (_faceProfiles.isEmpty) {
          _statusText =
              'No registered face embeddings found in local storage.\nPlease generate embeddings from the Student Directory screen first.';
        } else {
          _statusText =
              'Roster ready with ${_faceProfiles.length} registered students. Choose a scanning mode below.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _statusText = 'Failed to initialize Face SDK: $e';
      });
    }
  }

  Future<void> _startLiveAttendance() async {
    if (_faceProfiles.isEmpty || _isScanning) return;

    if (!Platform.isAndroid && !Platform.isIOS) {
      _runMockScan('Live Camera Sweep');
      return;
    }

    setState(() {
      _isScanning = true;
      _statusText = 'Launching Live Camera Attendance Sweep...';
    });

    try {
      final result = await _faceSdk.startLiveAttendance(
        roster: _faceProfiles,
        config: AttendanceConfig(
          type: _attendanceType,
          fontSize: _labelFontSize,
          detectedLabelField: _detectedLabelField,
          showMatchingPercentage: true,
          showDetectedLabel: true,
          showUnrecognizedLabel: true,
          unrecognizedLabel: _attendanceType == AttendanceType.TRANSPORT
              ? 'NOT IN THIS BUS'
              : 'UNREGISTERED VISITOR',
          onUnrecognizedFace: (unrecognizedFaces) {
            _handleLiveUnrecognizedFaces(unrecognizedFaces);
          },
        ),
      );

      if (!mounted) return;
      if (result != null) {
        _processAttendanceResult(result);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in Live Attendance: $e'),
          backgroundColor: const Color(0xFFFF2A54),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _startMultiPhotoAttendance() async {
    if (_faceProfiles.isEmpty || _isScanning) return;

    if (!Platform.isAndroid && !Platform.isIOS) {
      _runMockScan('Multi-Photo Group Scan');
      return;
    }

    setState(() {
      _isScanning = true;
      _statusText = 'Launching Multi-Photo Group Scan...';
    });

    try {
      final result = await _faceSdk.startMultiPhotoAttendance(
        roster: _faceProfiles,
        config: AttendanceConfig(
          type: _attendanceType,
          fontSize: _labelFontSize,
          detectedLabelField: _detectedLabelField,
          showMatchingPercentage: true,
          showDetectedLabel: true,
          showUnrecognizedLabel: true,
          unrecognizedLabel: _attendanceType == AttendanceType.TRANSPORT
              ? 'NOT IN THIS BUS'
              : 'UNREGISTERED VISITOR',
        ),
      );

      if (!mounted) return;
      if (result != null) {
        _processAttendanceResult(result);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in Photo Attendance: $e'),
          backgroundColor: const Color(0xFFFF2A54),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _startSinglePhotoScan(ImageSource source) async {
    if (_faceProfiles.isEmpty || _isScanning) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );

    if (pickedFile == null) return;

    setState(() {
      _isScanning = true;
      _statusText = 'Analyzing photo for face matches...';
    });

    try {
      final results = await _faceSdk.recognize(
        imagePath: pickedFile.path,
        profiles: _faceProfiles,
        mode: RecognitionMode.multi,
        threshold: defaultFaceMatchThreshold,
      );

      if (!mounted) return;

      final records = <AttendanceRecord>[];
      final unrecognizedRecords = <UnrecognizedFaceRecord>[];
      for (final res in results) {
        if (res.matched && res.personId != null) {
          records.add(
            AttendanceRecord(
              personId: res.personId!,
              confidenceScore: res.score,
              boundingBox: res.boundingBox,
              timestamp: DateTime.now(),
              sourceImagePath: pickedFile.path,
            ),
          );
        } else {
          unrecognizedRecords.add(
            UnrecognizedFaceRecord(
              confidenceScore: res.score,
              boundingBox: res.boundingBox,
              timestamp: DateTime.now(),
              sourceImagePath: pickedFile.path,
            ),
          );
        }
      }

      final attendanceRes = AttendanceResult(
        present: records,
        absentPersonIds: _faceProfiles
            .map((p) => p.personId)
            .where((id) => !records.any((r) => r.personId == id))
            .toList(),
        unrecognizedFaceCount: unrecognizedRecords.length,
        unrecognizedFaces: unrecognizedRecords,
        totalRosterCount: _faceProfiles.length,
        sessionStartTime: DateTime.now(),
        sessionEndTime: DateTime.now(),
        mode: AttendanceMode.batchImages,
        capturedImagePaths: [pickedFile.path],
      );

      _processAttendanceResult(attendanceRes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Single photo identification failed: $e'),
          backgroundColor: const Color(0xFFFF2A54),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _runMockScan(String scanModeName) {
    setState(() {
      _isScanning = true;
      _statusText = 'Running $scanModeName (Dev Mock Mode)...';
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      final random = Random();
      final candidates = _candidateStudentMap.values.toList();
      final records = <AttendanceRecord>[];

      final countToPick = min(candidates.length, random.nextInt(3) + 1);
      for (int i = 0; i < countToPick; i++) {
        final student = candidates[i];
        records.add(
          AttendanceRecord(
            personId: student.id.toString(),
            confidenceScore: 0.85 + (random.nextDouble() * 0.12),
            timestamp: DateTime.now(),
          ),
        );
      }

      final unrecognizedRecords = <UnrecognizedFaceRecord>[];
      final unrecCount = random.nextInt(2) + 1;
      for (int i = 0; i < unrecCount; i++) {
        unrecognizedRecords.add(
          UnrecognizedFaceRecord(
            score: 0.35 + (random.nextDouble() * 0.15),
            boundingBox: const FaceBoundingBox(
              left: 40,
              top: 40,
              right: 180,
              bottom: 200,
            ),
            timestamp: DateTime.now(),
          ),
        );
      }

      final mockResult = AttendanceResult(
        present: records,
        absentPersonIds: candidates
            .skip(countToPick)
            .map((s) => s.id.toString())
            .toList(),
        unrecognizedFaceCount: unrecognizedRecords.length,
        unrecognizedFaces: unrecognizedRecords,
        totalRosterCount: _faceProfiles.length,
        sessionStartTime: DateTime.now().subtract(const Duration(seconds: 15)),
        sessionEndTime: DateTime.now(),
        mode: AttendanceMode.liveStream,
      );

      _processAttendanceResult(mockResult);

      setState(() {
        _isScanning = false;
      });
    });
  }

  void _handleLiveUnrecognizedFaces(
    List<FaceRecognitionResult> unrecognizedFaces,
  ) {
    // When an unknown student is detected during live camera scanning, the camera session
    // automatically completes and navigates back to the app with the full AttendanceResult
    // and captured photo snapshot. The alert dialog will be displayed upon return
    // in _processAttendanceResult.
  }

  void _showUnrecognizedDialog({
    AttendanceResult? attendanceResult,
    List<UnrecognizedFaceRecord>? unrecognizedFaces,
    List<FaceRecognitionResult>? liveRecognitions,
  }) {
    if (_isAlertShowing || !mounted) return;
    _isAlertShowing = true;

    UnrecognizedStudentDialog.show(
      context: context,
      type: _attendanceType,
      attendanceResult: attendanceResult,
      unrecognizedFaces: unrecognizedFaces,
      liveRecognitions: liveRecognitions,
      onDismiss: () {
        _isAlertShowing = false;
      },
      onAction: () {
        _isAlertShowing = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _attendanceType == AttendanceType.TRANSPORT
                  ? '⚠️ Alert recorded: Transport Admin notified for Bus Route.'
                  : '⚠️ Student attendance exception flagged for manual review.',
            ),
            backgroundColor: _attendanceType == AttendanceType.TRANSPORT
                ? const Color(0xFFFFB300)
                : const Color(0xFF6C63FF),
          ),
        );
      },
      actionLabel: _attendanceType == AttendanceType.TRANSPORT
          ? 'NOTIFY DISPATCH'
          : 'FLAG EXCEPTION',
    );
  }

  void _processAttendanceResult(AttendanceResult result) {
    final identifyProvider = Provider.of<IdentifyProvider>(
      context,
      listen: false,
    );

    final presentIds = result.present.map((e) => e.personId).toSet();
    final matchedStudents = <Student>[];

    for (final idStr in presentIds) {
      final student = _candidateStudentMap[idStr];
      if (student != null) {
        matchedStudents.add(student);
      }
    }

    identifyProvider.setAttendanceResult(
      result,
      _candidateStudentMap.values.toList(),
    );

    setState(() {
      _lastAttendanceResult = result;
      _identifiedStudents = matchedStudents;
      _statusText =
          'Scan complete! ${matchedStudents.length} student(s) recognized.';
    });

    if (result.hasUnrecognizedFaces || result.unrecognizedFaceCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showUnrecognizedDialog(attendanceResult: result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopNavBar(),
              Expanded(
                child: _isPreparing
                    ? _buildPreparingState()
                    : _faceProfiles.isEmpty
                    ? _buildEmptyRosterState()
                    : _buildScannerHubContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        borderRadius: 18,
        bgColor: const Color(0x1AFFFFFF),
        bordercolor: const Color(0x336C63FF),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                          'FACE ATTENDANCE SCANNER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF8C85FF),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                '${_faceProfiles.length} ENROLLED',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00E676),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreparingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _statusText,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _prepProgress,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00E5FF),
                  ),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRosterState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_cell_rounded,
              size: 64,
              color: Color(0xFFFF2A54),
            ),
            const SizedBox(height: 20),
            Text(
              _statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              child: CustomButton(
                text: 'GO BACK',
                height: 44,
                borderRadius: 14,
                fontSize: 13,
                icon: Icons.arrow_back,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerHubContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scan Configuration (Type, Overlay Label, Font Size)
          _buildScanConfigurationCard(),
          const SizedBox(height: 20),

          // Section Title
          const Text(
            'SELECT SCAN MODE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF00E5FF),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Scan Options Grid
          Row(
            children: [
              Expanded(
                child: _buildScanModeOptionCard(
                  title: 'Live Camera Sweep',
                  subtitle: 'Real-time video scan across classroom',
                  badge: 'AUTOMATED',
                  icon: Icons.videocam_rounded,
                  iconColor: const Color(0xFF00E5FF),
                  onTap: _isScanning ? null : _startLiveAttendance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScanModeOptionCard(
                  title: 'Group Photo Scan',
                  subtitle: 'Multi-photo group snapshots',
                  badge: 'MULTI-PHOTO',
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xFF6C63FF),
                  onTap: _isScanning ? null : _startMultiPhotoAttendance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Single Photo Option
          _buildSinglePhotoOptionCard(),
          const SizedBox(height: 24),

          // Results Section
          if (_isScanning) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                ),
              ),
            ),
          ] else if (_lastAttendanceResult != null) ...[
            _buildResultsHeader(),
            const SizedBox(height: 14),
            _buildIdentifiedStudentsList(),
            if (_lastAttendanceResult!.unrecognizedFaces.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildUnrecognizedFacesList(
                _lastAttendanceResult!.unrecognizedFaces,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildScanModeOptionCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      bgColor: const Color(0x1AFFFFFF),
      bordercolor: iconColor.withValues(alpha: 0.3),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: iconColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinglePhotoOptionCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      bgColor: const Color(0x1AFFFFFF),
      bordercolor: Colors.white.withValues(alpha: 0.12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.center_focus_strong_rounded,
              color: Color(0xFF00E676),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Single Image Scan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pick or take a photo to recognize individual student faces',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.camera_alt_outlined,
              color: Color(0xFF00E5FF),
              size: 22,
            ),
            onPressed: _isScanning
                ? null
                : () => _startSinglePhotoScan(ImageSource.camera),
          ),
          IconButton(
            icon: const Icon(
              Icons.photo_library_outlined,
              color: Color(0xFF6C63FF),
              size: 22,
            ),
            onPressed: _isScanning
                ? null
                : () => _startSinglePhotoScan(ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    final result = _lastAttendanceResult!;
    final matchPercentage = result.attendancePercentage.toStringAsFixed(1);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      bgColor: const Color(0x2215102A),
      bordercolor: const Color(0x446C63FF),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECOGNITION SUMMARY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white54,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_identifiedStudents.length} / ${result.totalRosterCount} Identified',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '$matchPercentage% MATCH',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00E676),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.totalRosterCount > 0
                  ? _identifiedStudents.length / result.totalRosterCount
                  : 0.0,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF00E676),
              ),
              minHeight: 6,
            ),
          ),
          if (result.unrecognizedFaceCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:
                    (_attendanceType == AttendanceType.TRANSPORT
                            ? const Color(0xFFFFB300)
                            : const Color(0xFFFF2A54))
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      (_attendanceType == AttendanceType.TRANSPORT
                              ? const Color(0xFFFFB300)
                              : const Color(0xFFFF2A54))
                          .withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _attendanceType == AttendanceType.TRANSPORT
                        ? Icons.directions_bus_rounded
                        : Icons.warning_amber_rounded,
                    color: _attendanceType == AttendanceType.TRANSPORT
                        ? const Color(0xFFFFB300)
                        : const Color(0xFFFF2A54),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _attendanceType == AttendanceType.TRANSPORT
                              ? 'BUS TRANSPORT ALERT'
                              : 'UNRECOGNIZED FACE ALERT',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: _attendanceType == AttendanceType.TRANSPORT
                                ? const Color(0xFFFFB300)
                                : const Color(0xFFFF2A54),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _attendanceType == AttendanceType.TRANSPORT
                              ? '${result.unrecognizedFaceCount} student(s) detected not belonging to this bus.'
                              : '${result.unrecognizedFaceCount} unregistered student face(s) detected.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () =>
                        _showUnrecognizedDialog(attendanceResult: result),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (_attendanceType == AttendanceType.TRANSPORT
                                    ? const Color(0xFFFFB300)
                                    : const Color(0xFFFF2A54))
                                .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _attendanceType == AttendanceType.TRANSPORT
                              ? const Color(0xFFFFB300)
                              : const Color(0xFFFF2A54),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'VIEW ALERT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdentifiedStudentsList() {
    if (_identifiedStudents.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        borderRadius: 20,
        bgColor: const Color(0x1AFFFFFF),
        bordercolor: Colors.white12,
        child: const Center(
          child: Text(
            'No matching student face embeddings found in this scan.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECOGNIZED STUDENTS (${_identifiedStudents.length})',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF00E676),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _identifiedStudents.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final student = _identifiedStudents[index];
            final record = _lastAttendanceResult?.present.firstWhere(
              (r) => r.personId == student.id.toString(),
              orElse: () => AttendanceRecord(
                personId: student.id.toString(),
                confidenceScore: 0.9,
                timestamp: DateTime.now(),
              ),
            );

            final score = ((record?.confidenceScore ?? 0.9) * 100)
                .toStringAsFixed(1);

            return GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 16,
              bgColor: const Color(0x1AFFFFFF),
              bordercolor: Colors.white.withValues(alpha: 0.12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(
                      0xFF6C63FF,
                    ).withValues(alpha: 0.3),
                    backgroundImage:
                        student.photoUrl != null && student.photoUrl!.isNotEmpty
                        ? NetworkImage(student.photoUrl!)
                        : null,
                    child: student.photoUrl == null || student.photoUrl!.isEmpty
                        ? Text(
                            student.name.isNotEmpty
                                ? student.name[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
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
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ADM: ${student.admissionNumber} • CLASS ${student.standard}-${student.section}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '$score%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildScanConfigurationCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      bgColor: const Color(0x1F191438),
      bordercolor: const Color(0x336C63FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF00E5FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCAN CONFIGURATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose operation context, face overlay label, and font size',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Operation Type
          const Text(
            'OPERATION TYPE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF00E5FF),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTypeChoiceChip(
                  title: 'TRANSPORT (BUS)',
                  subtitle: 'Alerts if student is not on bus',
                  icon: Icons.directions_bus_rounded,
                  isSelected: _attendanceType == AttendanceType.TRANSPORT,
                  activeColor: const Color(0xFFFFB300),
                  onTap: () {
                    setState(() {
                      _attendanceType = AttendanceType.TRANSPORT;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTypeChoiceChip(
                  title: 'ATTENDANCE',
                  subtitle: 'Classroom roster roll-call',
                  icon: Icons.school_rounded,
                  isSelected: _attendanceType == AttendanceType.ATTENDANCE,
                  activeColor: const Color(0xFF6C63FF),
                  onTap: () {
                    setState(() {
                      _attendanceType = AttendanceType.ATTENDANCE;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Detected Label Field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CAMERA FACE OVERLAY LABEL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8C85FF),
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                _detectedLabelField.name.replaceAll('_', ' '),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E5FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLabelFieldChip('ID', DetectedLabelField.ID),
                const SizedBox(width: 8),
                _buildLabelFieldChip('NAME', DetectedLabelField.NAME),
                const SizedBox(width: 8),
                _buildLabelFieldChip('LABEL (ADM #)', DetectedLabelField.LABEL),
                const SizedBox(width: 8),
                _buildLabelFieldChip(
                  'NAME & ID',
                  DetectedLabelField.NAME_AND_ID,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Label Font Size
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LABEL FONT SIZE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8C85FF),
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${_labelFontSize.toInt()} pt',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E676),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final size in [10.0, 12.0, 14.0, 16.0, 18.0]) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          _labelFontSize = size;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _labelFontSize == size
                              ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _labelFontSize == size
                                ? const Color(0xFF6C63FF)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${size.toInt()}pt',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _labelFontSize == size
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: _labelFontSize == size
                                  ? Colors.white
                                  : Colors.white60,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChoiceChip({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? activeColor : Colors.white54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isSelected
                          ? activeColor.withValues(alpha: 0.9)
                          : Colors.white38,
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

  Widget _buildLabelFieldChip(String label, DetectedLabelField field) {
    final isSelected = _detectedLabelField == field;
    return InkWell(
      onTap: () {
        setState(() {
          _detectedLabelField = field;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00E5FF)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildUnrecognizedFacesList(
    List<UnrecognizedFaceRecord> unrecognized,
  ) {
    final isTransport = _attendanceType == AttendanceType.TRANSPORT;
    final alertColor = isTransport
        ? const Color(0xFFFFB300)
        : const Color(0xFFFF2A54);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isTransport
                      ? Icons.directions_bus_rounded
                      : Icons.warning_amber_rounded,
                  color: alertColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isTransport
                      ? 'BUS TRANSPORT ALERTS (${unrecognized.length})'
                      : 'UNRECOGNIZED FACES (${unrecognized.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: alertColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () =>
                  _showUnrecognizedDialog(unrecognizedFaces: unrecognized),
              child: Text(
                'EXPAND ALL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: alertColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: unrecognized.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final record = unrecognized[index];
            final box = record.boundingBox;
            final scorePct = ((record.confidenceScore) * 100).toStringAsFixed(
              1,
            );
            final hasImage =
                record.sourceImagePath != null &&
                record.sourceImagePath!.isNotEmpty &&
                File(record.sourceImagePath!).existsSync();

            return GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 16,
              bgColor: alertColor.withValues(alpha: 0.08),
              bordercolor: alertColor.withValues(alpha: 0.25),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: alertColor.withValues(alpha: 0.2),
                      child: hasImage
                          ? Image.file(
                              File(record.sourceImagePath!),
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.person_off_rounded,
                              color: alertColor,
                              size: 24,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTransport
                              ? 'Unregistered for Bus'
                              : 'Unknown Student #${index + 1}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Detected ${_formatTime(record.timestamp)}'
                          '${box != null ? ' • Box: [${box.left.toInt()}, ${box.top.toInt()}, ${box.width.toInt()}x${box.height.toInt()}]' : ''}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: alertColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: alertColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          record.confidenceScore > 0
                              ? '$scorePct% score'
                              : 'UNKNOWN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: alertColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _showUnrecognizedDialog(
                          unrecognizedFaces: [record],
                        ),
                        child: const Text(
                          'INSPECT',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
