import 'dart:async';

import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';

import 'local_face_store.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.sdk, this.store});

  final IcueFaceSdk? sdk;
  final FaceStore? store;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final IcueFaceSdk _sdk;
  late final FaceStore _store;
  late final Future<FaceSdkInfo> _initialization = _initialize();
  late final StreamSubscription<FaceTrackingResult> _trackingSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  List<FaceEnrollment> _enrollments = const <FaceEnrollment>[];
  String _cameraStatus = 'Enroll a face to begin';
  bool _cameraBusy = false;
  bool _tracking = false;

  @override
  void initState() {
    super.initState();
    _sdk = widget.sdk ?? IcueFaceSdk();
    _store = widget.store ?? LocalFaceStore();
    _trackingSubscription = _sdk.faceTrackingResults.listen(
      _handleTrackingResult,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _tracking = false;
          _cameraStatus = 'Tracking error: $error';
        });
      },
    );
  }

  Future<FaceSdkInfo> _initialize() async {
    await _sdk.initialize();
    final results = await Future.wait<Object>([_sdk.getInfo(), _store.load()]);
    _enrollments = results[1] as List<FaceEnrollment>;
    if (_enrollments.isNotEmpty) {
      _cameraStatus = '${_enrollments.length} enrolled face(s) ready';
    }
    return results[0] as FaceSdkInfo;
  }

  @override
  void dispose() {
    unawaited(_trackingSubscription.cancel());
    unawaited(_sdk.dispose());
    super.dispose();
  }

  void _handleTrackingResult(FaceTrackingResult frame) {
    if (!mounted) return;
    if (frame.stopped) {
      setState(() {
        _tracking = false;
        _cameraStatus = 'Tracking stopped';
      });
      return;
    }

    final matches =
        frame.recognitions
            .where((result) => result.matched && result.personId != null)
            .toList(growable: false)
          ..sort((first, second) => second.score.compareTo(first.score));
    setState(() {
      if (matches.isNotEmpty) {
        _cameraStatus = matches
            .map(
              (match) =>
                  '${match.personId} (${(match.score * 100).toStringAsFixed(1)}%)',
            )
            .join(', ');
      } else if (frame.faces.isEmpty) {
        _cameraStatus = 'No face detected';
      } else {
        _cameraStatus = '${frame.faces.length} unknown face(s)';
      }
    });
  }

  Future<void> _captureAndEnroll() async {
    if (_cameraBusy) return;
    setState(() {
      _cameraBusy = true;
      _cameraStatus = 'Opening capture camera…';
    });
    try {
      final embedding = await _sdk.captureEmbeddingWithCamera();
      if (!mounted) return;
      if (embedding == null) {
        setState(() => _cameraStatus = 'Enrollment cancelled');
        return;
      }

      setState(() => _cameraStatus = 'Face captured. Add a name to save it.');
      await _waitUntilFlutterIsResumed();
      if (!mounted) return;
      final name = await _requestName();
      if (!mounted) return;
      if (name == null) {
        setState(() => _cameraStatus = 'Captured embedding was not saved');
        return;
      }

      final enrollment = FaceEnrollment(name: name, embedding: embedding);
      final updated = await _store.upsert(_enrollments, enrollment);
      if (!mounted) return;
      setState(() {
        _enrollments = updated;
        _cameraStatus = '${enrollment.name} enrolled successfully';
      });
      _showMessage('${enrollment.name} saved on this device');
    } catch (error) {
      if (mounted) setState(() => _cameraStatus = 'Enrollment error: $error');
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  Future<void> _waitUntilFlutterIsResumed() async {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      final resumed = Completer<void>();
      late final AppLifecycleListener listener;
      listener = AppLifecycleListener(
        onResume: () {
          listener.dispose();
          if (!resumed.isCompleted) resumed.complete();
        },
      );
      await resumed.future;
    }
    await Future<void>.delayed(Duration.zero);
  }

  Future<String?> _requestName() async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return null;
    return showDialog<String>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (_) => const _NameDialog(),
    );
  }

  Future<void> _startTracking() async {
    if (_cameraBusy || _tracking) return;
    if (_enrollments.isEmpty) {
      _showMessage('Enroll at least one face first');
      return;
    }
    setState(() {
      _cameraBusy = true;
      _cameraStatus = 'Opening recognition camera…';
    });
    try {
      await _sdk.startFaceTracking(
        profiles: _enrollments.map((item) => item.toProfile()).toList(),
      );
      if (!mounted) return;
      setState(() {
        _tracking = true;
        _cameraStatus = 'Looking for enrolled faces…';
      });
    } catch (error) {
      if (mounted) setState(() => _cameraStatus = 'Tracking error: $error');
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  Future<void> _stopTracking() async {
    await _sdk.stopFaceTracking();
    if (!mounted) return;
    setState(() {
      _tracking = false;
      _cameraStatus = 'Tracking stopped';
    });
  }

  Future<void> _startLiveClassAttendance() async {
    if (_cameraBusy || _tracking) return;
    if (_enrollments.isEmpty) {
      _showMessage('Enroll at least one student face first');
      return;
    }
    setState(() {
      _cameraBusy = true;
      _cameraStatus = 'Opening Live Class Attendance camera…';
    });
    try {
      final roster = _enrollments.map((item) => item.toProfile()).toList();
      final result = await _sdk.startLiveAttendance(roster: roster);
      if (!mounted) return;
      if (result == null) {
        setState(() => _cameraStatus = 'Live attendance cancelled');
        return;
      }
      setState(
        () => _cameraStatus =
            'Attendance complete: ${result.present.length}/${result.totalRosterCount} present',
      );
      _showAttendanceSummary(result);
    } catch (error) {
      if (mounted) setState(() => _cameraStatus = 'Attendance error: $error');
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  Future<void> _startMultiPhotoClassAttendance() async {
    if (_cameraBusy || _tracking) return;
    if (_enrollments.isEmpty) {
      _showMessage('Enroll at least one student face first');
      return;
    }
    setState(() {
      _cameraBusy = true;
      _cameraStatus = 'Opening Multi-Photo Group Attendance camera…';
    });
    try {
      final roster = _enrollments.map((item) => item.toProfile()).toList();
      final result = await _sdk.startMultiPhotoAttendance(roster: roster);
      if (!mounted) return;
      if (result == null) {
        setState(() => _cameraStatus = 'Multi-photo attendance cancelled');
        return;
      }
      setState(
        () => _cameraStatus =
            'Multi-photo attendance complete: ${result.present.length}/${result.totalRosterCount} present',
      );
      _showAttendanceSummary(result);
    } catch (error) {
      if (mounted) setState(() => _cameraStatus = 'Attendance error: $error');
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  void _showAttendanceSummary(AttendanceResult result) {
    final navContext = _navigatorKey.currentContext;
    if (navContext == null) return;
    showModalBottomSheet<void>(
      context: navContext,
      backgroundColor: const Color(0xFF0F1A2A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => _AttendanceSummarySheet(
          result: result,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Future<void> _removeEnrollment(FaceEnrollment enrollment) async {
    final updated = await _store.remove(_enrollments, enrollment.name);
    if (!mounted) return;
    setState(() {
      _enrollments = updated;
      _cameraStatus = '${enrollment.name} removed';
    });
  }

  void _showMessage(String message) {
    _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF0B1422),
        ),
        scaffoldBackgroundColor: const Color(0xFF050B14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1422),
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.school, color: Color(0xFF00E5FF), size: 20),
              SizedBox(width: 8),
              Text(
                'iCue School Attendance',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: FutureBuilder<FaceSdkInfo>(
            future: _initialization,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('SDK error: ${snapshot.error}'));
              }
              final info = snapshot.data;
              if (info == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _FaceDemoContent(
                info: info,
                enrollments: _enrollments,
                cameraStatus: _cameraStatus,
                cameraBusy: _cameraBusy,
                tracking: _tracking,
                onEnroll: _captureAndEnroll,
                onStartTracking: _startTracking,
                onStopTracking: _stopTracking,
                onStartLiveAttendance: _startLiveClassAttendance,
                onStartMultiPhotoAttendance: _startMultiPhotoClassAttendance,
                onRemove: _removeEnrollment,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F1A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x3300E5FF)),
      ),
      title: const Text('Enroll Student Profile'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 60,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Student Name / Roll No.',
            hintText: 'For example, Alex Rivera (Roll #102)',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00E5FF)),
            ),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter student name or roll number'
              : null,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Discard', style: TextStyle(color: Colors.grey)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: const Color(0xFF041217),
          ),
          onPressed: _save,
          child: const Text('Save Student'),
        ),
      ],
    );
  }
}

class _FaceDemoContent extends StatelessWidget {
  const _FaceDemoContent({
    required this.info,
    required this.enrollments,
    required this.cameraStatus,
    required this.cameraBusy,
    required this.tracking,
    required this.onEnroll,
    required this.onStartTracking,
    required this.onStopTracking,
    required this.onStartLiveAttendance,
    required this.onStartMultiPhotoAttendance,
    required this.onRemove,
  });

  final FaceSdkInfo info;
  final List<FaceEnrollment> enrollments;
  final String cameraStatus;
  final bool cameraBusy;
  final bool tracking;
  final VoidCallback onEnroll;
  final VoidCallback onStartTracking;
  final VoidCallback onStopTracking;
  final VoidCallback onStartLiveAttendance;
  final VoidCallback onStartMultiPhotoAttendance;
  final ValueChanged<FaceEnrollment> onRemove;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1726),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x3300E5FF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.school, color: Color(0xFF00E5FF), size: 18),
              const SizedBox(width: 10),
              Text(
                'SDK v${info.sdkVersion}  •  Student Face Engine  •  On-Device',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '1. Student Enrollment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF1F5F9),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enroll student face profiles for automated classroom attendance.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: const Color(0xFF041217),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: cameraBusy || tracking ? null : onEnroll,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text(
              'OPEN STUDENT ENROLLMENT',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Enrolled Students (${enrollments.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF1F5F9),
              ),
            ),
            if (enrollments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x3300E676),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'REGISTERED',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (enrollments.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1422),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x1F94A3B8)),
            ),
            child: const Text(
              'No student profiles enrolled on this device. Tap above to enroll a student.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          )
        else
          ...enrollments.map(
            (enrollment) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1726),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x2200E5FF)),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0x2200E5FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school, color: Color(0xFF00E5FF)),
                ),
                title: Text(
                  enrollment.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  '${enrollment.embedding.length}-dim biometric vector',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Remove ${enrollment.name}',
                  onPressed: tracking ? null : () => onRemove(enrollment),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFFF5252),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 28),
        const Text(
          '2. Whole Class Attendance Modes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF1F5F9),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Take complete class attendance using live video scan or multi-group photo snapshots.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF041217),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: cameraBusy || enrollments.isEmpty
                      ? null
                      : onStartLiveAttendance,
                  icon: const Icon(Icons.videocam_outlined, size: 20),
                  label: const Text(
                    'LIVE SCAN',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: cameraBusy || enrollments.isEmpty
                      ? null
                      : onStartMultiPhotoAttendance,
                  icon: const Icon(Icons.collections_outlined, size: 20),
                  label: const Text(
                    'MULTI-PHOTO',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          '3. Single Live Tracking Stream',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF1F5F9),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Continuous live camera feed with real-time bounding box tracking overlay.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: tracking
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5252),
                    side: const BorderSide(color: Color(0xFFFF5252)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: cameraBusy ? null : onStopTracking,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text(
                    'STOP LIVE STREAM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Color(0x6694A3B8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: cameraBusy || enrollments.isEmpty
                      ? null
                      : onStartTracking,
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text(
                    'START LIVE STREAM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1422),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x3300E5FF)),
          ),
          child: Row(
            children: [
              if (cameraBusy)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                )
              else
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Text(
                  cameraStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Campus Biometric Privacy Notice: Student face embeddings are processed strictly on-device without cloud transmission.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _AttendanceSummarySheet extends StatelessWidget {
  const _AttendanceSummarySheet({
    required this.result,
    required this.scrollController,
  });

  final AttendanceResult result;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.assignment_turned_in,
                color: Color(0xFF00E5FF),
                size: 24,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Attendance Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x3300E676),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E676)),
                ),
                child: Text(
                  '${result.attendancePercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Chip(
                backgroundColor: const Color(0xFF1E293B),
                avatar: Icon(
                  result.mode == AttendanceMode.liveStream
                      ? Icons.videocam
                      : Icons.photo_library,
                  size: 16,
                  color: const Color(0xFF00E5FF),
                ),
                label: Text(
                  result.mode == AttendanceMode.liveStream
                      ? 'Live Camera'
                      : 'Multi-Photo Group',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                backgroundColor: const Color(0xFF1E293B),
                avatar: const Icon(
                  Icons.people,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
                label: Text(
                  '${result.present.length}/${result.totalRosterCount} Present',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0x2200E5FF), height: 24),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                if (result.present.isNotEmpty) ...[
                  const Text(
                    'PRESENT STUDENTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E676),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...result.present.map(
                    (rec) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1726),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.check_circle,
                          color: Color(0xFF00E676),
                        ),
                        title: Text(
                          rec.personId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Text(
                          '${(rec.confidenceScore * 100).toStringAsFixed(1)}% match',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (result.absentPersonIds.isNotEmpty) ...[
                  const Text(
                    'ABSENT STUDENTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5252),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...result.absentPersonIds.map(
                    (id) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1726),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.cancel,
                          color: Color(0xFFFF5252),
                        ),
                        title: Text(
                          id,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Text(
                          'Absent',
                          style: TextStyle(
                            color: Color(0xFFFF5252),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (result.capturedImagePaths.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'CAPTURED GROUP PHOTOS FOR SERVER UPLOAD (${result.capturedImagePaths.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...result.capturedImagePaths.map(
                    (path) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1726),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x3300E5FF)),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.image,
                          color: Color(0xFF00E5FF),
                        ),
                        title: Text(
                          path.split('/').last,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          path,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.cloud_upload_outlined,
                          color: Color(0xFF00E676),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF041217),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close Summary'),
            ),
          ),
        ],
      ),
    );
  }
}
