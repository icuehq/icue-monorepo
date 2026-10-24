import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/facility_task.dart';
import '../../models/facility_task_status.dart';
import '../../providers/common_provider.dart';
import '../../providers/facility_provider.dart';
import '../../services/file_picker_utils.dart';
import '../../utils/app_utils.dart';

/// Screen designed specifically for facility cleaners in Basic Facility Management mode.
/// UX Optimization:
/// - 70-75% screen: Live camera viewfinder for instant on-site photo capture (no gallery).
/// - Interactive photo slots above shutter: "fill the boxes" visual cue.
/// - Bottom panel: Clean task details + large "Submit Cleaning" button (zero wasted space).
class BasicFacilityTaskDetailPage extends StatefulWidget {
  const BasicFacilityTaskDetailPage({super.key, this.qrCode, this.taskId});

  final String? qrCode;
  final int? taskId;

  @override
  State<BasicFacilityTaskDetailPage> createState() =>
      _BasicFacilityTaskDetailPageState();
}

class _BasicFacilityTaskDetailPageState
    extends State<BasicFacilityTaskDetailPage>
    with WidgetsBindingObserver {
  FacilityTask? _activeFacilityTask;
  List<FacilityTask> _availableTasks = [];
  CameraController? _cameraController;
  String? _errorMessage;
  String? _facilityName;
  String? _facilityPath;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isTakingPhoto = false;
  bool _isTorchOn = false;
  final TextEditingController _remarksController = TextEditingController();
  final Map<String, String> _remotePhotoUrls = {};
  final List<XFile> _selectedPhotos = [];
  bool _showShutterFlash = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTaskData();
      _initCamera();
    });
  }

  String get _displayFacilityPath {
    final raw = _facilityPath;
    if (raw == null || raw.trim().isEmpty) return '';
    return raw
        .split('||')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' • ');
  }

  int get _maxPhotos {
    final common = context.read<CommonProvider>();
    final limit = common.appSettings?.fmsCnfg?.maxCleaningImages ?? 3;
    return limit > 0 ? limit : 3;
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      // Explicitly turn off flash to disable pre-capture AE metering delay
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}

      setState(() {
        _cameraController = controller;
      });
    } catch (e) {
      debugPrint('Camera init error (fallback enabled): $e');
    }
  }

  Future<void> _loadTaskData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prov = context.read<FacilityProvider>();

    try {
      final shouldFetch =
          prov.cleaningTasksQr.isEmpty ||
          (widget.qrCode != null &&
              widget.qrCode!.isNotEmpty &&
              prov.currentFacilityQr?.qrCode.toLowerCase() !=
                  widget.qrCode!.trim().toLowerCase());

      if (shouldFetch && widget.qrCode != null && widget.qrCode!.isNotEmpty) {
        await prov.getCleaningTasksByQR(
          DateTime.now(),
          widget.qrCode!.trim(),
          isBasicFacilityMgmt: true,
        );
      }

      final tasks = prov.cleaningTasksQr.isNotEmpty
          ? prov.cleaningTasksQr
          : prov.cleaningTasks;
      _availableTasks = tasks;

      if (tasks.isNotEmpty) {
        FacilityTask? taskToSelect;
        if (widget.taskId != null) {
          taskToSelect = tasks.cast<FacilityTask?>().firstWhere(
            (t) => t?.id == widget.taskId,
            orElse: () => null,
          );
        }

        taskToSelect ??= tasks.cast<FacilityTask?>().firstWhere(
          (t) => t?.taskStatus == FacilityTaskStatus.inProgress,
          orElse: () => tasks.cast<FacilityTask?>().firstWhere(
            (t) => t?.taskStatus == FacilityTaskStatus.pending,
            orElse: () => tasks.first,
          ),
        );

        if (taskToSelect != null) {
          _activeFacilityTask = taskToSelect;
          _facilityName =
              taskToSelect.scheduleName ??
              prov.currentFacilityQr?.name ??
              'Cleaning Area';
          _facilityPath =
              prov.currentFacilityQr?.facilityPath ?? taskToSelect.facilityPath;

          // Auto-start task if it is still pending
          if (taskToSelect.taskStatus == FacilityTaskStatus.pending &&
              taskToSelect.id != null) {
            await prov.startCleaningTask(taskToSelect.id!);
            _activeFacilityTask = taskToSelect.copyWith(status: 'IN_PROGRESS');
          }
        }
      } else {
        _errorMessage =
            prov.errorMessage ??
            'No cleaning tasks scheduled for this location today.';
      }
    } catch (e) {
      _errorMessage = 'Failed to load task details. Please check connection.';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectTask(FacilityTask task) {
    if (task.id == null || task.id == _activeFacilityTask?.id) return;
    final prov = context.read<FacilityProvider>();
    setState(() {
      _activeFacilityTask = task;
      _facilityName =
          task.scheduleName ?? prov.currentFacilityQr?.name ?? 'Cleaning Area';
      _facilityPath = prov.currentFacilityQr?.facilityPath ?? task.facilityPath;
      _selectedPhotos.clear();
      _remotePhotoUrls.clear();
    });
  }

  Future<void> _capturePhoto() async {
    if (_selectedPhotos.length >= _maxPhotos) {
      AppUtils.showErrorMessage(
        context,
        'Maximum $_maxPhotos photos already added.',
      );
      return;
    }

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      if (_isTakingPhoto) return;
      setState(() {
        _isTakingPhoto = true;
        _showShutterFlash = true;
      });

      // Instant physical feedback right when button is tapped
      HapticFeedback.lightImpact();

      // Reset shutter flash animation after 70ms
      Future.delayed(const Duration(milliseconds: 70), () {
        if (mounted) setState(() => _showShutterFlash = false);
      });

      try {
        final photo = await _cameraController!.takePicture();
        if (mounted) {
          setState(() {
            _selectedPhotos.add(photo);
          });
          HapticFeedback.mediumImpact();
        }
      } catch (e) {
        if (mounted) {
          AppUtils.showErrorMessage(context, 'Failed to capture photo: $e');
        }
      } finally {
        if (mounted) setState(() => _isTakingPhoto = false);
      }
    } else {
      // Fallback for tests, emulators, or cameras initializing
      try {
        final photo = await FilePickerUtils().pickImage(ImageSource.camera);
        if (photo != null && mounted) {
          setState(() {
            _selectedPhotos.add(photo);
          });
          HapticFeedback.mediumImpact();
        }
      } catch (e) {
        AppUtils.showErrorMessage(context, 'Could not capture photo: $e');
      }
    }
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      final nextMode = _isTorchOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(nextMode);
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {}
  }

  void _removePhoto(int index) {
    if (index >= 0 && index < _selectedPhotos.length) {
      setState(() {
        _selectedPhotos.removeAt(index);
      });
      HapticFeedback.selectionClick();
    }
  }

  void _previewLocalImage(XFile file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 520, maxWidth: 520),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: Colors.black87,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Photo Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      child: kIsWeb
                          ? Image.network(file.path, fit: BoxFit.contain)
                          : Image.file(File(file.path), fit: BoxFit.contain),
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

  Future<void> _submitCleaning() async {
    final taskId = _activeFacilityTask?.id;
    if (taskId == null) {
      AppUtils.showErrorMessage(context, 'No valid task selected.');
      return;
    }

    if (_selectedPhotos.isEmpty) {
      AppUtils.showErrorMessage(
        context,
        'Please take at least 1 photo of the cleaned area before submitting.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final prov = context.read<FacilityProvider>();

    try {
      AppUtils.showLoadingDialog(context, 'Submitting cleaning photos...');

      final currentStatus =
          _activeFacilityTask?.taskStatus ?? FacilityTaskStatus.pending;

      if (currentStatus == FacilityTaskStatus.pending) {
        await prov.startCleaningTask(taskId, context: context);
      }

      final docIds = await prov.uploadCleaningTaskPhotos(
        photos: _selectedPhotos,
        context: context,
      );

      if (docIds.isEmpty && _selectedPhotos.isNotEmpty) {
        if (mounted) {
          AppUtils.hideLoadingDialog(context);
          AppUtils.showErrorMessage(
            context,
            'Photo upload failed. Please try again.',
          );
        }
        return;
      }

      final checklistResults = <Map<String, dynamic>>[];

      final remarks = _remarksController.text.trim().isNotEmpty
          ? _remarksController.text.trim()
          : 'Cleaning completed';

      final success = await prov.completeCleaningTask(
        taskId,
        remarks,
        checklistResults,
        [],
        docIds,
        context: context,
      );

      if (mounted) {
        AppUtils.hideLoadingDialog(context);
        if (success) {
          setState(() {
            _activeFacilityTask = _activeFacilityTask?.copyWith(
              status: 'COMPLETED',
            );
          });
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      if (mounted) {
        AppUtils.hideLoadingDialog(context);
        AppUtils.showErrorMessage(context, 'Error submitting task: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Camera Viewport with Top Navigation Overlay & Bottom Shutter Controls
  Widget _buildCameraViewport() {
    final theme = Theme.of(context);
    final limit = _maxPhotos;
    final canTakeMore = _selectedPhotos.length < limit;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Live Feed or Placeholder
        if (_cameraController != null && _cameraController!.value.isInitialized)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = _cameraController!.value.previewSize;
                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: size != null ? size.height : constraints.maxWidth,
                      height: size != null ? size.width : constraints.maxHeight,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                );
              },
            ),
          )
        else
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white54,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Camera Viewfinder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _capturePhoto,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Capture Photo'),
                  ),
                ],
              ),
            ),
          ),

        // Shutter flash visual feedback
        if (_showShutterFlash)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: Container(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),

        // TOP NAVIGATION & LOCATION HEADER OVERLAY (Fixed directly under status bar)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  // Back Button
                  _GlassCircleButton(
                    icon: Icons.arrow_back,
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),

                  // Location Tag Pill
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF4ADE80),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _facilityName ?? 'Cleaning Area',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                if (_displayFacilityPath.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    _displayFacilityPath,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Flash Torch Toggle
                  _GlassCircleButton(
                    icon: _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: _isTorchOn ? Colors.amber : Colors.white,
                    onPressed: _toggleTorch,
                  ),
                ],
              ),
            ),
          ),
        ),

        // BOTTOM SHUTTER & PHOTO SLOTS OVERLAY
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo Slots / Fill-the-boxes preview strip
              _buildPhotoSlotsStrip(limit),
              const SizedBox(height: 16),

              // Big Native Shutter Button & Counter
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: canTakeMore && !_isTakingPhoto
                        ? _capturePhoto
                        : null,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: canTakeMore
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          width: 4.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _isTakingPhoto ? 54 : 64,
                          height: _isTakingPhoto ? 54 : 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: canTakeMore
                                ? theme.colorScheme.primary
                                : Colors.grey.shade600,
                          ),
                          child: _isTakingPhoto
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 32,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Visual photo slots: Cleaners immediately see how many photos are taken vs remaining
  Widget _buildPhotoSlotsStrip(int limit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(limit, (index) {
          final isCaptured = index < _selectedPhotos.length;
          final isNextSlot = index == _selectedPhotos.length;

          if (isCaptured) {
            final file = _selectedPhotos[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => _previewLocalImage(file),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                        image: DecorationImage(
                          image: kIsWeb
                              ? NetworkImage(file.path)
                              : ResizeImage(
                                      FileImage(File(file.path)),
                                      width: 120,
                                      height: 120,
                                    )
                                    as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -5,
                    right: -5,
                    child: GestureDetector(
                      onTap: () => _removePhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Empty slot placeholder
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isNextSlot ? const Color(0xFF4ADE80) : Colors.white24,
                  width: isNextSlot ? 1.8 : 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: isNextSlot ? const Color(0xFF4ADE80) : Colors.white38,
                  size: 20,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Natural-Height Bottom Panel: Zero awkward blank space
  Widget _buildBottomDataPanel() {
    final startTime = _activeFacilityTask?.scheduledStartTime;
    final cleanerName = _activeFacilityTask?.assignedUser;
    final count = _selectedPhotos.length;
    final limit = _maxPhotos;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Facility Title + Status Badge + Photo Counter
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_displayFacilityPath.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.apartment_rounded,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _displayFacilityPath,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                        ],
                        Text(
                          _facilityName ?? 'Cleaning Task',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          startTime != null
                              ? 'Shift: $startTime • ${cleanerName ?? 'Cleaner'}'
                              : 'Assigned: ${cleanerName ?? 'Cleaner'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _activeFacilityTask?.taskStatus ==
                              FacilityTaskStatus.completed
                          ? const Color(0xFFDCFCE7)
                          : _activeFacilityTask?.taskStatus ==
                                FacilityTaskStatus.pending
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _activeFacilityTask?.taskStatus ==
                              FacilityTaskStatus.completed
                          ? 'Completed'
                          : _activeFacilityTask?.taskStatus ==
                                FacilityTaskStatus.pending
                          ? 'Pending'
                          : 'In Progress',
                      style: TextStyle(
                        color:
                            _activeFacilityTask?.taskStatus ==
                                FacilityTaskStatus.completed
                            ? const Color(0xFF16A34A)
                            : _activeFacilityTask?.taskStatus ==
                                  FacilityTaskStatus.pending
                            ? const Color(0xFFD97706)
                            : const Color(0xFF1D4ED8),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Photo Count Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? const Color(0xFFDCFCE7)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count/$limit',
                      style: TextStyle(
                        color: count > 0
                            ? const Color(0xFF16A34A)
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              // Multi-task selector if more than 1 task available
              if (_availableTasks.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _availableTasks.map((t) {
                      final isSelected = t.id == _activeFacilityTask?.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            t.scheduleName ?? 'Task #${t.id}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) => _selectTask(t),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Big Full-Width Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: count > 0
                        ? const Color(0xFF16A34A)
                        : Colors.grey.shade400,
                    elevation: count > 0 ? 3 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 24),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting...'
                        : (count > 0
                              ? 'Submit Cleaning ($count Photos)'
                              : 'Take Photo to Submit'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitCleaning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Completed View if already completed
  Widget _buildCompletedScreen() {
    final startTime = _activeFacilityTask?.scheduledStartTime;
    final endTime = _activeFacilityTask?.scheduledEndTime;
    final cleanerName = _activeFacilityTask?.assignedUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Clean Location')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  children: [
                    // 1. Hero Celebration Icon with Soft Rings
                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF86EFAC),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF16A34A,
                              ).withValues(alpha: 0.15),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Main Headline & Subtitle
                    const Text(
                      'Cleaning Completed Today!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Task was verified and submitted successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Facility Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Facility Name + Status Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _facilityName ?? 'Facility Area',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF86EFAC),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Color(0xFF16A34A),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Completed',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Facility Path
                          if (_displayFacilityPath.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.apartment_rounded,
                                    size: 15,
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _displayFacilityPath,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ),

                          // Meta details row: Cleaner + Time
                          Row(
                            children: [
                              // Shift Time
                              if (startTime != null) ...[
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          endTime != null
                                              ? '$startTime - $endTime'
                                              : startTime,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // Cleaner
                              if (cleanerName != null &&
                                  cleanerName.isNotEmpty) ...[
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          cleanerName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Sticky Bottom Actions Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.qr_code_scanner, size: 22),
                      label: const Text(
                        'Scan Next QR Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      onPressed: () {
                        context.pushReplacement(
                          '/facility-qr-scanner?mode=basic',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        Icons.home_outlined,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                      label: Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      onPressed: () => context.go('/'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Finding cleaning task...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Clean Location'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.red.shade600,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loadTaskData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => context.pushReplacement(
                        '/facility-qr-scanner?mode=basic',
                      ),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isCompleted =
        _activeFacilityTask?.taskStatus == FacilityTaskStatus.completed;

    if (isCompleted) {
      return _buildCompletedScreen();
    }

    // Main Camera Viewport + Natural Bottom Panel
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 1. TOP LIVE CAMERA VIEWPORT (Fills available space)
          Expanded(child: _buildCameraViewport()),

          // 2. BOTTOM COMPACT TASK INFO & SUBMIT BAR (Natural height, no empty gaps)
          _buildBottomDataPanel(),
        ],
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
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
