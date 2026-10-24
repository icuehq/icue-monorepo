import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/facility_task.dart';
import '../../models/facility_task_status.dart';
import '../../providers/facility_provider.dart';

class FacilityQrScannerPage extends StatefulWidget {
  const FacilityQrScannerPage({
    super.key,
    this.onScanned,
    this.isBasic = false,
  });

  final void Function(String qrCode)? onScanned;
  final bool isBasic;

  @override
  State<FacilityQrScannerPage> createState() => _FacilityQrScannerPageState();
}

class _FacilityQrScannerPageState extends State<FacilityQrScannerPage>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _animationController;
  late final Animation<double> _scanAnimation;

  bool _isProcessing = false;
  bool _isTorchOn = false;
  CameraFacing _facing = CameraFacing.back;

  // Basic facility processing state
  String? _scannedCode;
  int _basicStep = 1; // 1: checking schedule, 2: starting task, 3: task ready
  String? _basicErrorMessage;
  FacilityTask? _targetTask;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue?.trim();

    if (code != null && code.isNotEmpty) {
      if (widget.onScanned != null) {
        setState(() => _isProcessing = true);
        HapticFeedback.mediumImpact();
        widget.onScanned!(code);
        if (mounted) Navigator.of(context).pop(code);
      } else if (widget.isBasic) {
        _processBasicWorkflow(code);
      } else {
        setState(() => _isProcessing = true);
        HapticFeedback.mediumImpact();
        final targetRoute = Uri(
          path: '/facility-qr-tasks',
          queryParameters: {'qrCode': code},
        ).toString();
        context.pushReplacement(targetRoute);
      }
    }
  }

  Future<void> _processBasicWorkflow(String code) async {
    setState(() {
      _isProcessing = true;
      _scannedCode = code;
      _basicStep = 1;
      _basicErrorMessage = null;
      _targetTask = null;
    });

    HapticFeedback.mediumImpact();

    try {
      await _scannerController.stop();
    } catch (_) {}

    final prov = context.read<FacilityProvider>();

    try {
      // Step 1: Call getFacilityTasksByQrCode with IsBasicFacilityMgmt: true
      final fetchSuccess = await prov.getCleaningTasksByQR(
        DateTime.now(),
        code,
        isBasicFacilityMgmt: true,
      );

      if (!mounted) return;

      if (!fetchSuccess) {
        setState(() {
          _basicErrorMessage = prov.errorMessage ??
              'Could not find cleaning tasks for this QR code.';
        });
        return;
      }

      final tasks = prov.cleaningTasksQr;
      if (tasks.isEmpty) {
        setState(() {
          _basicErrorMessage =
              'No cleaning tasks scheduled for this location today.';
        });
        return;
      }

      // Select active task: inProgress > pending > first
      final task = tasks.firstWhere(
        (t) => t.taskStatus == FacilityTaskStatus.inProgress,
        orElse: () => tasks.firstWhere(
          (t) => t.taskStatus == FacilityTaskStatus.pending,
          orElse: () => tasks.first,
        ),
      );
      _targetTask = task;

      // If task is completed, navigate to details to view completion state
      if (task.taskStatus == FacilityTaskStatus.completed) {
        setState(() => _basicStep = 3);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          final targetRoute = Uri(
            path: '/basic-facility-task-detail',
            queryParameters: {
              if (task.id != null) 'taskId': task.id.toString(),
              'qrCode': code,
            },
          ).toString();
          context.pushReplacement(targetRoute);
        }
        return;
      }

      // Step 2: Immediately call startCleaningTask
      setState(() => _basicStep = 2);

      if (task.taskStatus == FacilityTaskStatus.pending && task.id != null) {
        final startSuccess = await prov.startCleaningTask(task.id!);
        if (!mounted) return;

        if (!startSuccess) {
          setState(() {
            _basicErrorMessage = prov.errorMessage ??
                'Failed to start cleaning task. Please try again.';
          });
          return;
        }
      }

      // Step 3: Success! Both API calls succeeded
      setState(() => _basicStep = 3);
      HapticFeedback.heavyImpact();

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        final targetRoute = Uri(
          path: '/basic-facility-task-detail',
          queryParameters: {
            if (task.id != null) 'taskId': task.id.toString(),
            'qrCode': code,
          },
        ).toString();
        context.pushReplacement(targetRoute);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _basicErrorMessage =
              'An error occurred while setting up the cleaning task.';
        });
      }
    }
  }

  Future<void> _resetScanner() async {
    setState(() {
      _isProcessing = false;
      _scannedCode = null;
      _basicErrorMessage = null;
      _basicStep = 1;
      _targetTask = null;
    });
    try {
      await _scannerController.start();
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    try {
      await _scannerController.switchCamera();
      setState(() {
        _facing = _facing == CameraFacing.back
            ? CameraFacing.front
            : CameraFacing.back;
      });
    } catch (_) {}
  }

  void _showManualEntrySheet() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.keyboard, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Enter Facility Code Manually',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If the QR code is damaged or unreadable, enter the code printed under the QR code.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Facility QR Code',
                        hintText: 'e.g. FAC-BLD-A-FL1-WR01',
                        prefixIcon: const Icon(Icons.qr_code_2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => controller.clear(),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter a valid code';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) =>
                          _submitManual(ctx, controller, formKey),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Find Tasks'),
                            onPressed: () =>
                                _submitManual(ctx, controller, formKey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _submitManual(
    BuildContext ctx,
    TextEditingController controller,
    GlobalKey<FormState> formKey,
  ) {
    if (!formKey.currentState!.validate()) return;
    final code = controller.text.trim();
    Navigator.pop(ctx);

    if (widget.onScanned != null) {
      widget.onScanned!(code);
      if (mounted) Navigator.of(context).pop(code);
    } else if (widget.isBasic) {
      _processBasicWorkflow(code);
    } else {
      final targetRoute = Uri(
        path: '/facility-qr-tasks',
        queryParameters: {'qrCode': code},
      ).toString();
      context.pushReplacement(targetRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final scanAreaSize = (size.width * 0.72).clamp(240.0, 320.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Live Scanner View
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_outlined,
                        color: Colors.white70,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Camera error: ${error.errorCode.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please ensure camera permissions are granted or use manual entry below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        icon: const Icon(Icons.keyboard),
                        label: const Text('Enter Code Manually'),
                        onPressed: _showManualEntrySheet,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Viewfinder Overlay with Dark Scrim
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.65),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanAreaSize,
                    height: scanAreaSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Viewfinder Corner Markers & Animated Laser
          Center(
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize,
              child: Stack(
                children: [
                  // Corner markers
                  CustomPaint(
                    size: Size(scanAreaSize, scanAreaSize),
                    painter: _QrCornerPainter(
                      color: theme.colorScheme.primary,
                      cornerLength: 28,
                      strokeWidth: 4,
                      borderRadius: 20,
                    ),
                  ),

                  // Animated Scanning Laser Bar
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: scanAreaSize * _scanAnimation.value,
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.0,
                                ),
                                theme.colorScheme.primary,
                                Colors.white,
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.0,
                                ),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.8,
                                ),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Top App Bar with Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  _GlassCircleButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    widget.isBasic
                        ? 'Scan Location QR'
                        : 'Scan Facility QR',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                  // Torch toggle
                  _GlassCircleButton(
                    icon: _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: _isTorchOn ? Colors.amber : Colors.white,
                    onPressed: _toggleTorch,
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Controls & Instructions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white70,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Align the facility QR code within frame',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Switch Camera
                        _ScannerBottomActionButton(
                          icon: Icons.cameraswitch_outlined,
                          label: 'Flip',
                          onTap: _switchCamera,
                        ),
                        // Manual Entry
                        _ScannerBottomActionButton(
                          icon: Icons.keyboard_alt_outlined,
                          label: 'Enter Code',
                          isPrimary: true,
                          onTap: _showManualEntrySheet,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. Processing / Success Indicator or Basic Facility Workflow Overlay
          if (_isProcessing)
            widget.isBasic
                ? _buildBasicProcessingOverlay()
                : Container(
                    color: Colors.black54,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'QR Code Detected!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Loading cleaning tasks...',
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildBasicProcessingOverlay() {
    final theme = Theme.of(context);
    final isError = _basicErrorMessage != null;
    final isDone = _basicStep >= 3;

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Icon Badge
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isError
                        ? const Color(0xFFFEE2E2)
                        : (isDone
                            ? const Color(0xFFDCFCE7)
                            : theme.colorScheme.primary
                                .withValues(alpha: 0.12)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isError
                        ? Icons.warning_amber_rounded
                        : (isDone
                            ? Icons.check_circle_rounded
                            : Icons.qr_code_scanner),
                    color: isError
                        ? const Color(0xFFDC2626)
                        : (isDone
                            ? const Color(0xFF16A34A)
                            : theme.colorScheme.primary),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  isError
                      ? 'Task Setup Issue'
                      : (isDone
                          ? 'Cleaning Task Ready!'
                          : 'Setting Up Cleaning Task'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isError
                        ? const Color(0xFF991B1B)
                        : (isDone
                            ? const Color(0xFF16A34A)
                            : Colors.black87),
                  ),
                ),
                const SizedBox(height: 6),

                // Scanned QR Code Pill
                if (_scannedCode != null && _scannedCode!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _targetTask?.scheduleName != null
                                ? '${_targetTask!.scheduleName!} • ${_scannedCode!}'
                                : _scannedCode!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Content: Error Alert or Multi-step Progress
                if (isError) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _basicErrorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7F1D1D),
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Error Actions
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text(
                        'Scan Again',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _resetScanner,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          onPressed: () {
                            if (_scannedCode != null) {
                              _processBasicWorkflow(_scannedCode!);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.keyboard, size: 18),
                          label: const Text('Manual'),
                          onPressed: () {
                            _resetScanner();
                            _showManualEntrySheet();
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Multi-Step Progress Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Step 1: Checking Schedule
                        _buildStepRow(
                          stepNumber: 1,
                          title: 'Verifying Schedule',
                          activeSubtitle:
                              'Fetching cleaning task for location...',
                          completedSubtitle: 'Cleaning schedule verified',
                          isActive: _basicStep == 1,
                          isCompleted: _basicStep > 1,
                          primaryColor: theme.colorScheme.primary,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child:
                              Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ),
                        // Step 2: Starting Cleaning Task
                        _buildStepRow(
                          stepNumber: 2,
                          title: 'Starting Cleaning Task',
                          activeSubtitle:
                              'Activating task and shift timer...',
                          completedSubtitle: 'Task activated successfully',
                          isActive: _basicStep == 2,
                          isCompleted: _basicStep >= 3,
                          primaryColor: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isDone)
                    TextButton(
                      onPressed: _resetScanner,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required int stepNumber,
    required String title,
    required String activeSubtitle,
    required String completedSubtitle,
    required bool isActive,
    required bool isCompleted,
    required Color primaryColor,
  }) {
    Widget indicator;
    if (isCompleted) {
      indicator = const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF16A34A),
        size: 22,
      );
    } else if (isActive) {
      indicator = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: primaryColor,
        ),
      );
    } else {
      indicator = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade400, width: 1.8),
        ),
        child: Center(
          child: Text(
            '$stepNumber',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        indicator,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCompleted
                      ? const Color(0xFF16A34A)
                      : (isActive ? Colors.black87 : Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isCompleted
                    ? completedSubtitle
                    : (isActive
                        ? activeSubtitle
                        : 'Waiting for schedule...'),
                style: TextStyle(
                  fontSize: 12,
                  color: isCompleted
                      ? const Color(0xFF16A34A)
                      : (isActive
                          ? Colors.grey.shade700
                          : Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}

class _ScannerBottomActionButton extends StatelessWidget {
  const _ScannerBottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isPrimary
          ? theme.colorScheme.primary
          : Colors.black.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPrimary ? theme.colorScheme.primary : Colors.white24,
        ),
      ),
      elevation: isPrimary ? 4 : 0,
      shadowColor: isPrimary
          ? theme.colorScheme.primary.withValues(alpha: 0.4)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPrimary ? theme.colorScheme.onPrimary : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? theme.colorScheme.onPrimary : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrCornerPainter extends CustomPainter {
  _QrCornerPainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
    required this.borderRadius,
  });

  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final l = cornerLength;

    // Top Left Corner
    final tlPath = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(l, 0);
    canvas.drawPath(tlPath, paint);

    // Top Right Corner
    final trPath = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, l);
    canvas.drawPath(trPath, paint);

    // Bottom Left Corner
    final blPath = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..quadraticBezierTo(0, h, r, h)
      ..lineTo(l, h);
    canvas.drawPath(blPath, paint);

    // Bottom Right Corner
    final brPath = Path()
      ..moveTo(w - l, h)
      ..lineTo(w - r, h)
      ..quadraticBezierTo(w, h, w, h - r)
      ..lineTo(w, h - l);
    canvas.drawPath(brPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
