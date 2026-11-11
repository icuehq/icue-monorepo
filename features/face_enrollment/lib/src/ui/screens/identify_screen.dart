import 'dart:io';
import 'dart:math';

import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/providers/identify_provider.dart';
import 'package:face_enrollment/src/providers/student_provider.dart';
import 'package:face_enrollment/src/storage/embedding_store.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:face_enrollment/src/ui/widgets/ambient_background.dart';
import 'package:face_enrollment/src/ui/widgets/identify_nav_bar.dart';
import 'package:face_enrollment/src/ui/widgets/identify_states.dart';
import 'package:face_enrollment/src/ui/widgets/scan_hub.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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

  final List<FaceProfile> _faceProfiles = [];
  final Map<String, Student> _candidateStudentMap = {};

  AttendanceResult? _lastAttendanceResult;
  List<Student> _identifiedStudents = [];

  @override
  void initState() {
    super.initState();
    _faceSdk = GetIt.I<IcueFaceSdk>();
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
      final embeddingStore = GetIt.I<EmbeddingStore>();
      final candidates = studentProvider.filteredStudents.isNotEmpty
          ? studentProvider.filteredStudents
          : studentProvider.students;

      _faceProfiles.clear();
      _candidateStudentMap.clear();

      for (int index = 0; index < candidates.length; index++) {
        final student = candidates[index];
        if (embeddingStore.has(student.id)) {
          final savedEmbedding = embeddingStore.get(student.id);
          if (savedEmbedding != null &&
              savedEmbedding.embedding.length == faceEmbeddingSize &&
              savedEmbedding.embedding.every((val) => val.isFinite)) {
            _candidateStudentMap[student.id.toString()] = student;
            _faceProfiles.add(
              FaceProfile(
                personId: student.id.toString(),
                embedding: savedEmbedding.embedding,
                name: student.name,
              ),
            );
          }
        }
        if (mounted) {
          setState(() {
            _prepProgress = 0.2 + (0.8 * (index + 1) / candidates.length);
          });
        }
      }

      if (!mounted) return;

      setState(() {
        _isPreparing = false;
        if (_faceProfiles.isEmpty) {
          _statusText = 'No registered face embeddings found in local cache. Sync from cloud to continue.';
        } else {
          _statusText =
              'Roster ready with ${_faceProfiles.length} registered students. Choose a scan mode.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _statusText = 'Failed to initialize Face SDK: $error';
      });
    }
  }

  Future<void> _handleSyncAndReload() async {
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );
    try {
      setState(() {
        _isPreparing = true;
        _statusText = 'Syncing embeddings from server...';
        _prepProgress = 0.3;
      });

      await studentProvider.syncEmbeddingsFromServer();
      await _initAndLoadRoster();
    } catch (error) {
      if (mounted) {
        setState(() {
          _isPreparing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync embeddings: $error'),
            backgroundColor: context.scheme.error,
          ),
        );
      }
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
        config: const AttendanceConfig(
          unrecognizedLabel: 'UNREGISTERED VISITOR',
        ),
      );

      if (!mounted) return;
      if (result != null) {
        _processAttendanceResult(result);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in Live Attendance: $error'),
          backgroundColor: context.scheme.error,
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
      _runMockScan('Group Photo Scan');
      return;
    }

    setState(() {
      _isScanning = true;
      _statusText = 'Launching Multi-Photo Group Scan...';
    });

    try {
      final result = await _faceSdk.startMultiPhotoAttendance(
        roster: _faceProfiles,
        config: const AttendanceConfig(
          unrecognizedLabel: 'UNREGISTERED VISITOR',
        ),
      );

      if (!mounted) return;
      if (result != null) {
        _processAttendanceResult(result);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in Photo Attendance: $error'),
          backgroundColor: context.scheme.error,
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
      );

      if (!mounted) return;

      final records = <AttendanceRecord>[];
      for (final res in results) {
        if (res.matched && res.personId != null) {
          records.add(
            AttendanceRecord(
              personId: res.personId!,
              confidenceScore: res.score,
              boundingBox: res.boundingBox,
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      final attendanceRes = AttendanceResult(
        present: records,
        absentPersonIds: _faceProfiles
            .map((profile) => profile.personId)
            .where((id) => !records.any((rec) => rec.personId == id))
            .toList(),
        unrecognizedFaceCount: results.where((item) => !item.matched).length,
        totalRosterCount: _faceProfiles.length,
        sessionStartTime: DateTime.now(),
        sessionEndTime: DateTime.now(),
        mode: AttendanceMode.batchImages,
      );

      _processAttendanceResult(attendanceRes);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Single photo identification failed: $error'),
          backgroundColor: context.scheme.error,
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
      for (int index = 0; index < countToPick; index++) {
        final student = candidates[index];
        records.add(
          AttendanceRecord(
            personId: student.id.toString(),
            confidenceScore: 0.85 + (random.nextDouble() * 0.12),
            timestamp: DateTime.now(),
          ),
        );
      }

      final mockResult = AttendanceResult(
        present: records,
        absentPersonIds: candidates
            .skip(countToPick)
            .map((student) => student.id.toString())
            .toList(),
        unrecognizedFaceCount: random.nextInt(2),
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

  void _processAttendanceResult(AttendanceResult result) {
    final identifyProvider = Provider.of<IdentifyProvider>(
      context,
      listen: false,
    );

    final presentIds = result.present.map((rec) => rec.personId).toSet();
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
          'Scan complete: ${matchedStudents.length} student(s) recognized.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scheme.surface,
      appBar: IdentifyAppBar(
        rosterSize: _faceProfiles.length,
        statusText: _statusText,
        onRefreshRoster: _isPreparing ? null : _initAndLoadRoster,
      ),
      body: AmbientBackground(
        child: SafeArea(
          top: false,
          child: _isPreparing
              ? PreparingState(progress: _prepProgress, statusText: _statusText)
              : _faceProfiles.isEmpty
              ? EmptyRosterState(
                  statusText: _statusText,
                  onBack: () => Navigator.of(context).pop(),
                  onSync: _handleSyncAndReload,
                )
              : ScanHub(
                  isScanning: _isScanning,
                  attendanceResult: _lastAttendanceResult,
                  identifiedStudents: _identifiedStudents,
                  onLiveAttendance: _startLiveAttendance,
                  onMultiPhoto: _startMultiPhotoAttendance,
                  onSinglePhoto: _startSinglePhotoScan,
                ),
        ),
      ),
    );
  }
}
