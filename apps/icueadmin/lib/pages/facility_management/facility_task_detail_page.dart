import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../dialogs/fail_cleaning_task_dialog.dart';
import '../../dialogs/skip_cleaning_task_dialog.dart';
import '../../models/cleaning_task_response.dart';
import '../../providers/facility_provider.dart';
import '../../services/file_picker_utils.dart';
import '../../utils/app_utils.dart';

class _ChecklistItemState {
  _ChecklistItemState({
    required this.itemId,
    required this.name,
    this.description = '',
    this.required = false,
    this.completed = false,
    this.remarks = '',
    this.status = '',
  });

  final String itemId;
  final String name;
  final String description;
  final bool required;
  bool completed;
  String remarks;
  String status;
}

class FacilityTaskDetailPage extends StatefulWidget {
  const FacilityTaskDetailPage({super.key, required this.taskId});

  final int taskId;

  @override
  State<FacilityTaskDetailPage> createState() => _FacilityTaskDetailPageState();
}

class _FacilityTaskDetailPageState extends State<FacilityTaskDetailPage> {
  final TextEditingController _overallRemarksController =
      TextEditingController();

  List<_ChecklistItemState> _checklist = [];
  final List<XFile> _beforePhotos = [];
  final List<XFile> _afterPhotos = [];
  Map<String, String> _remotePhotoUrls = {};
  bool _isSubmitting = false;
  bool _isDetailsExpanded = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadTaskDetails();
    });
  }

  @override
  void dispose() {
    _overallRemarksController.dispose();
    super.dispose();
  }

  Future<void> _loadTaskDetails() async {
    final prov = context.read<FacilityProvider>();
    await prov.getCleaningTaskDetails(widget.taskId);

    final task = prov.cleaningTaskDetails;
    if (task != null && mounted) {
      setState(() {
        if (task.checklistSnapshot != null &&
            task.checklistSnapshot!.isNotEmpty) {
          _checklist = task.checklistSnapshot!.map((s) {
            final matchingResult = task.checklistResults?.firstWhere(
              (r) => r is Map && r['ItemId'] == s.itemId,
              orElse: () => null,
            );
            final statusStr = matchingResult != null && matchingResult is Map
                ? matchingResult['Status']?.toString().toLowerCase() ?? ''
                : '';
            final isDone =
                matchingResult != null &&
                matchingResult is Map &&
                (matchingResult['Completed'] == true ||
                    statusStr == 'pass' ||
                    statusStr == 'completed');
            final remarks = matchingResult != null && matchingResult is Map
                ? (matchingResult['Remarks']?.toString() ?? '')
                : '';

            return _ChecklistItemState(
              itemId: s.itemId ?? '',
              name: s.name ?? '',
              description: s.description ?? '',
              required: s.required ?? false,
              completed: isDone,
              remarks: remarks,
              status: statusStr,
            );
          }).toList();
        } else {
          _checklist = [];
        }

        final remarks =
            (task.completionRemarks != null &&
                task.completionRemarks!.isNotEmpty)
            ? task.completionRemarks!
            : (task.failureRemarks != null && task.failureRemarks!.isNotEmpty)
            ? task.failureRemarks!
            : (task.skipRemarks != null && task.skipRemarks!.isNotEmpty)
            ? task.skipRemarks!
            : '';
        if (remarks.isNotEmpty) {
          _overallRemarksController.text = remarks;
        }
      });

      // Extract and fetch remote document photos
      final docIds = <String>[];
      for (var p in task.beforePhotos ?? []) {
        if (p is Map && p['DocumentId'] != null) {
          docIds.add(p['DocumentId'].toString());
        } else if (p is String && p.isNotEmpty) {
          docIds.add(p);
        }
      }
      for (var p in task.afterPhotos ?? []) {
        if (p is Map && p['DocumentId'] != null) {
          docIds.add(p['DocumentId'].toString());
        } else if (p is String && p.isNotEmpty) {
          docIds.add(p);
        }
      }

      if (docIds.isNotEmpty) {
        prov.getImagesByDocumentIds(documentIds: docIds).then((urls) {
          if (mounted) {
            setState(() {
              _remotePhotoUrls = urls;
            });
          }
        });
      }
    }
  }

  Future<void> _pickPhoto({
    required bool isBefore,
    required ImageSource source,
  }) async {
    try {
      final photo = await FilePickerUtils().pickImage(source);
      if (photo != null && mounted) {
        setState(() {
          if (isBefore) {
            _beforePhotos.add(photo);
          } else {
            _afterPhotos.add(photo);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorMessage(context, 'Failed to capture photo: $e');
      }
    }
  }

  void _showPhotoSourceSheet({required bool isBefore}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isBefore
                      ? 'Add Before-Cleaning Photo'
                      : 'Add After-Cleaning Photo',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                if (!kIsWeb)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: const Text(
                        'Take Photo with Camera',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPhoto(
                          isBefore: isBefore,
                          source: ImageSource.camera,
                        );
                      },
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.purple,
                      ),
                    ),
                    title: const Text(
                      'Choose from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickPhoto(
                        isBefore: isBefore,
                        source: ImageSource.gallery,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _previewLocalImage({required XFile file, required String title}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
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
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
                      minScale: 0.5,
                      maxScale: 4.0,
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

  void _previewNetworkImage({required String url, required String title}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 550, maxWidth: 550),
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
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white70,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
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

  String? _formatDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    if (diff.isNegative) return null;

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}'.trim();
    } else if (minutes > 0) {
      return '$minutes min${seconds > 0 && minutes < 5 ? ' $seconds sec' : ''}';
    } else {
      return '$seconds sec';
    }
  }

  Future<void> _handleCompleteTask(CleaningTask task) async {
    final prov = context.read<FacilityProvider>();

    final completedCount = _checklist.where((c) => c.completed).length;
    if (_checklist.isNotEmpty &&
        completedCount == 0 &&
        _overallRemarksController.text.trim().isEmpty) {
      AppUtils.showErrorMessage(
        context,
        'Please mark at least one checklist item or add remarks before completing.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      AppUtils.showLoadingDialog(
        context,
        'Uploading photos and completing task...',
      );

      // 1. Upload Before photos
      final beforeDocIds = await prov.uploadCleaningTaskPhotos(
        photos: _beforePhotos,
        context: context,
      );

      // 2. Upload After photos
      final afterDocIds = await prov.uploadCleaningTaskPhotos(
        photos: _afterPhotos,
        context: context,
      );

      // Extract existing remote doc IDs
      final allBeforeIds = <String>[];
      for (var p in task.beforePhotos ?? []) {
        if (p is Map && p['DocumentId'] != null) {
          allBeforeIds.add(p['DocumentId'].toString());
        } else if (p is String && p.isNotEmpty) {
          allBeforeIds.add(p);
        }
      }
      allBeforeIds.addAll(beforeDocIds);

      final allAfterIds = <String>[];
      for (var p in task.afterPhotos ?? []) {
        if (p is Map && p['DocumentId'] != null) {
          allAfterIds.add(p['DocumentId'].toString());
        } else if (p is String && p.isNotEmpty) {
          allAfterIds.add(p);
        }
      }
      allAfterIds.addAll(afterDocIds);

      final remarks = _overallRemarksController.text.trim().isNotEmpty
          ? _overallRemarksController.text.trim()
          : 'Cleaning completed as per checklist';

      final checklistResults = _checklist
          .map(
            (c) => {
              'ItemId': c.itemId,
              'Name': c.name,
              'Completed': c.completed,
              'Remarks': c.remarks,
            },
          )
          .toList();

      // 3. Complete Cleaning Task API
      final success = await prov.completeCleaningTask(
        task.id ?? widget.taskId,
        remarks,
        checklistResults,
        allBeforeIds,
        allAfterIds,
        context: context,
      );

      if (mounted) {
        AppUtils.hideLoadingDialog(context);
        if (success) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppUtils.hideLoadingDialog(context);
        AppUtils.showErrorMessage(context, 'Error completing task: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prov = context.watch<FacilityProvider>();
    final task = prov.cleaningTaskDetails;

    if (prov.loading && task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task Details')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_late_outlined,
                size: 56,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              const Text(
                'Task details not found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Could not load cleaning task #${widget.taskId}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: Size.zero),
                icon: const Icon(Icons.refresh),
                onPressed: _loadTaskDetails,
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final status = task.taskStatus;
    final isPending = status.isPending;
    final isInProgress = status.isInProgress;
    final isEditable = isInProgress; // Checkbox editing is only for inProgress

    final title = (task.scheduleName ?? '').isNotEmpty
        ? task.scheduleName
        : 'Cleaning Task #${task.id ?? widget.taskId}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh details',
            onPressed: _loadTaskDetails,
          ),
        ],
      ),
      bottomNavigationBar: (isPending || isInProgress)
          ? _buildBottomActionBar(task, theme)
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _loadTaskDetails(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Task Header & Status Card
              _buildHeaderCard(task, theme),

              const SizedBox(height: 14),

              // 2. Status-Specific Context Banner (Alert / Completed / Progress Summary)
              _buildStatusContextBanner(task, theme),

              const SizedBox(height: 14),

              // 3. Metadata & Task Information Card
              _buildTaskInfoCard(task, theme),

              const SizedBox(height: 14),

              // 4. Checklist Section
              _buildChecklistSection(task, isEditable, theme),

              const SizedBox(height: 14),

              // 5. Before Photos Section
              _buildPhotosSection(
                title: 'Before Cleaning Photos',
                icon: Icons.camera_front_outlined,
                remotePhotos: task.beforePhotos ?? [],
                localPhotos: _beforePhotos,
                isBefore: true,
                isEditable: isEditable,
                theme: theme,
              ),

              const SizedBox(height: 14),

              // 6. After Photos Section
              _buildPhotosSection(
                title: 'After Cleaning Photos',
                icon: Icons.camera_enhance_outlined,
                remotePhotos: task.afterPhotos ?? [],
                localPhotos: _afterPhotos,
                isBefore: false,
                isEditable: isEditable,
                theme: theme,
              ),

              const SizedBox(height: 14),

              // 7. Remarks Section
              _buildRemarksSection(task, isEditable, theme),

              const SizedBox(height: 14),

              // 8. Task Activity Timeline & Audit Trail
              _buildTimelineSection(task, theme),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 1. Task Header Card
  // ---------------------------------------------------------
  Widget _buildHeaderCard(CleaningTask task, ThemeData theme) {
    final status = task.taskStatus;
    final statusColor = status.color;
    final statusIcon = status.icon;

    final timeRange =
        (task.scheduledStartTime?.isNotEmpty == true &&
            task.scheduledEndTime?.isNotEmpty == true)
        ? '${task.scheduledStartTime} - ${task.scheduledEndTime}'
        : task.scheduledStartTime;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Task Title & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (task.scheduleName ?? '').isNotEmpty
                            ? task.scheduleName ?? ''
                            : 'Cleaning Task #${task.id ?? widget.taskId}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'Task #${task.id ?? widget.taskId}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          if (task.scheduleId != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                'Schedule #${task.scheduleId}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 22),

            // Assigned Staff Row
            if (task.assignedUser?.isNotEmpty == true ||
                task.assignedRole?.isNotEmpty == true) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.assignedUser ?? 'Unassigned',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (task.assignedRole?.isNotEmpty == true)
                          Text(
                            task.assignedRole ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Schedule Date & Time Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        task.scheduledDate.formattedFullDate(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  if (timeRange?.isNotEmpty == true)
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeRange ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 2. Status-Specific Context Banner
  // ---------------------------------------------------------
  Widget _buildStatusContextBanner(CleaningTask task, ThemeData theme) {
    final status = task.taskStatus;

    if (status.isCompleted) {
      final duration = _formatDuration(task.startedAt, task.completedAt);
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Task Completed Successfully',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF065F46),
                  ),
                ),
                const Spacer(),
                if (duration != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          duration,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Completed by ${task.completedBy ?? task.assignedUser ?? 'Staff'}${task.completedAt != null ? ' on ${task.completedAt.formattedFullDateTime()}' : ''}.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
            ),
            if (task.completionRemarks?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Completion Remarks:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.completionRemarks ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1F2937),
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

    if (status.isInProgress) {
      final elapsed = _formatDuration(task.startedAt, DateTime.now());
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.pending_actions_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Cleaning In Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                const Spacer(),
                if (elapsed != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timelapse,
                          size: 12,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Elapsed: $elapsed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Started by ${task.startedBy ?? task.assignedUser ?? 'Staff'}${task.startedAt != null ? ' at ${task.startedAt.formattedTime()}' : ''}. Complete the checklist items below and capture photos before submission.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8)),
            ),
          ],
        ),
      );
    }

    if (status.isFailed) {
      final reason = (task.failureRemarks?.isNotEmpty == true)
          ? task.failureRemarks!
          : (task.skipRemarks?.isNotEmpty == true)
          ? task.skipRemarks!
          : 'No failure reason provided.';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cancel_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Task Reported as Failed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const Spacer(),
                if (task.failedAt != null)
                  Text(
                    task.failedAt.formattedTime(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Reported by ${task.failedBy ?? 'Staff'}${task.failedAt != null ? ' on ${task.failedAt.formattedFullDateTime()}' : ''}.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Failure Reason / Remarks:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (status.isSkipped) {
      final reason = (task.skipRemarks?.isNotEmpty == true)
          ? task.skipRemarks!
          : 'No skip reason provided.';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.skip_next_rounded,
                  color: Color(0xFFEA580C),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Task Skipped',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF9A3412),
                  ),
                ),
                const Spacer(),
                if (task.skippedAt != null)
                  Text(
                    task.skippedAt.formattedTime(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC2410C),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Skipped by ${task.skippedBy ?? 'Staff'}${task.skippedAt != null ? ' on ${task.skippedAt.formattedFullDateTime()}' : ''}.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFC2410C)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Skip Reason:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Default: Pending State Banner
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Task Ready to Start',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap "Start Task" below when you arrive at the facility to begin.',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 3. Task Metadata & Details Card
  // ---------------------------------------------------------
  Widget _buildTaskInfoCard(CleaningTask task, ThemeData theme) {
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _isDetailsExpanded = !_isDetailsExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Task & Facility Details',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(
                    _isDetailsExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (_isDetailsExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildMetadataRow('Task ID', '#${task.id ?? widget.taskId}'),
                  if (task.scheduleId != null)
                    _buildMetadataRow('Schedule ID', '#${task.scheduleId}'),
                  if (task.cleaningTemplateId != null)
                    _buildMetadataRow(
                      'Template',
                      '#${task.cleaningTemplateId}${task.templateVersion != null ? ' (v${task.templateVersion})' : ''}',
                    ),
                  if (task.facilityId != null)
                    _buildMetadataRow('Facility ID', '#${task.facilityId}'),
                  if (task.facilityTypeId != null)
                    _buildMetadataRow(
                      'Facility Type ID',
                      '#${task.facilityTypeId}',
                    ),
                  if (task.zoneId != null)
                    _buildMetadataRow('Zone ID', '#${task.zoneId}'),
                  if (task.branchId != null)
                    _buildMetadataRow('Branch ID', '#${task.branchId}'),
                  if (task.createdBy != null && task.createdBy!.isNotEmpty)
                    _buildMetadataRow('Created By', task.createdBy!),
                  if (task.createdDate != null)
                    _buildMetadataRow(
                      'Created Date',
                      task.createdDate.formattedFullDateTime(),
                    ),
                  if (task.updatedBy != null && task.updatedBy!.isNotEmpty)
                    _buildMetadataRow('Updated By', task.updatedBy!),
                  if (task.updatedDate != null)
                    _buildMetadataRow(
                      'Updated Date',
                      task.updatedDate.formattedFullDateTime(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 4. Checklist Section
  // ---------------------------------------------------------
  Widget _buildChecklistSection(
    CleaningTask task,
    bool isEditable,
    ThemeData theme,
  ) {
    final completedCount = _checklist.where((c) => c.completed).length;
    final totalCount = _checklist.length;
    final allDone = totalCount > 0 && completedCount == totalCount;
    final percentage = totalCount > 0
        ? ((completedCount / totalCount) * 100).toInt()
        : 0;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Cleaning Checklist',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: allDone
                        ? const Color(0xFFECFDF5)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: allDone
                          ? const Color(0xFFA7F3D0)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '$completedCount/$totalCount ($percentage%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: allDone
                          ? const Color(0xFF059669)
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),

            if (totalCount > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completedCount / totalCount,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    allDone
                        ? const Color(0xFF10B981)
                        : theme.colorScheme.primary,
                  ),
                  minHeight: 6,
                ),
              ),
            ],

            if (isEditable && totalCount > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  icon: Icon(
                    allDone ? Icons.remove_done : Icons.done_all,
                    size: 16,
                  ),
                  label: Text(
                    allDone ? 'Uncheck All' : 'Check All',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      for (var item in _checklist) {
                        item.completed = !allDone;
                      }
                    });
                  },
                ),
              ),
            ],

            if (!isEditable && task.taskStatus.isPending && totalCount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Checklist can be marked after starting the task.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            if (_checklist.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.playlist_remove_outlined,
                        size: 36,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No checklist items configured',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _checklist.length,
                separatorBuilder: (_, _) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final item = _checklist[index];

                  if (isEditable) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          item.completed = !item.completed;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: item.completed,
                              activeColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  item.completed = val ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: item.completed
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: item.completed
                                                ? Colors.black87
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (item.required)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'Required',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (item.description.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      item.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Read-only checklist display for Completed/Failed/Skipped/Pending
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: item.completed
                          ? const Color(0xFFF0FDF4)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: item.completed
                            ? const Color(0xFFDCFCE7)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.completed
                              ? Icons.check_circle_rounded
                              : (task.taskStatus.isPending
                                    ? Icons.radio_button_unchecked
                                    : Icons.cancel_outlined),
                          color: item.completed
                              ? const Color(0xFF10B981)
                              : (task.taskStatus.isPending
                                    ? Colors.grey
                                    : Colors.red.shade400),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: item.completed
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: item.completed
                                            ? const Color(0xFF065F46)
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  if (item.required)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Required',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (item.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                              if (item.remarks.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Remarks: ${item.remarks}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 5 & 6. Photos Section (Before & After)
  // ---------------------------------------------------------
  Widget _buildPhotosSection({
    required String title,
    required IconData icon,
    required List<dynamic> remotePhotos,
    required List<XFile> localPhotos,
    required bool isBefore,
    required bool isEditable,
    required ThemeData theme,
  }) {
    final totalPhotos = remotePhotos.length + localPhotos.length;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: totalPhotos > 0
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalPhotos',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: totalPhotos > 0
                          ? theme.colorScheme.primary
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                if (isEditable)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_a_photo_outlined, size: 15),
                    label: const Text('Add', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showPhotoSourceSheet(isBefore: isBefore),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (totalPhotos == 0)
              if (isEditable)
                InkWell(
                  onTap: () => _showPhotoSourceSheet(isBefore: isBefore),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to capture / attach photo',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(
                    child: Text(
                      'No photos attached for this section',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // Remote photos from API
                  ...remotePhotos.map((photo) {
                    final docId = photo is Map
                        ? photo['DocumentId']?.toString()
                        : photo.toString();
                    final imageUrl = docId != null
                        ? _remotePhotoUrls[docId]
                        : null;

                    return InkWell(
                      onTap: imageUrl != null && imageUrl.isNotEmpty
                          ? () => _previewNetworkImage(
                              url: imageUrl,
                              title: title,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 95,
                        height: 95,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, _, _) => const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                ),
                              )
                            : const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                      ),
                    );
                  }),

                  // Local newly captured photos
                  ...localPhotos.map((file) {
                    return Stack(
                      children: [
                        InkWell(
                          onTap: () =>
                              _previewLocalImage(file: file, title: title),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 95,
                            height: 95,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: kIsWeb
                                ? Image.network(file.path, fit: BoxFit.cover)
                                : Image.file(
                                    File(file.path),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        if (isEditable)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  localPhotos.remove(file);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 7. Remarks Section
  // ---------------------------------------------------------
  Widget _buildRemarksSection(
    CleaningTask task,
    bool isEditable,
    ThemeData theme,
  ) {
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notes_rounded, size: 22),
                SizedBox(width: 8),
                Text(
                  'Task Remarks / Notes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isEditable)
              TextFormField(
                controller: _overallRemarksController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter any general remarks or cleaning notes...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  _overallRemarksController.text.trim().isNotEmpty
                      ? _overallRemarksController.text.trim()
                      : 'No remarks recorded for this task.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _overallRemarksController.text.trim().isNotEmpty
                        ? Colors.black87
                        : Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 8. Task Activity & Audit Timeline
  // ---------------------------------------------------------
  Widget _buildTimelineSection(CleaningTask task, ThemeData theme) {
    final status = task.taskStatus;

    final events = <_TimelineEvent>[];

    // 1. Created
    if (task.createdDate != null || task.createdBy != null) {
      events.add(
        _TimelineEvent(
          title: 'Task Created',
          time: task.createdDate.formattedFullDateTime(),
          actor: task.createdBy != null && task.createdBy!.isNotEmpty
              ? 'By ${task.createdBy}'
              : '',
          icon: Icons.add_circle_outline,
          color: Colors.blue.shade600,
        ),
      );
    }

    // 2. Scheduled
    if (task.scheduledDate != null) {
      final timeStr =
          (task.scheduledStartTime != null && task.scheduledEndTime != null)
          ? '${task.scheduledStartTime} - ${task.scheduledEndTime}'
          : task.scheduledStartTime ?? '';
      events.add(
        _TimelineEvent(
          title: 'Scheduled Time Window',
          time:
              '${task.scheduledDate.formattedFullDate()}${timeStr.isNotEmpty ? ', $timeStr' : ''}',
          actor: task.assignedUser != null && task.assignedUser!.isNotEmpty
              ? 'Assigned to ${task.assignedUser}'
              : '',
          icon: Icons.calendar_today_outlined,
          color: Colors.purple.shade600,
        ),
      );
    }

    // 3. Started
    if (task.startedAt != null) {
      events.add(
        _TimelineEvent(
          title: 'Cleaning Started',
          time: task.startedAt.formattedFullDateTime(),
          actor: task.startedBy != null && task.startedBy!.isNotEmpty
              ? 'By ${task.startedBy}'
              : '',
          icon: Icons.play_circle_outline,
          color: const Color(0xFF2563EB),
        ),
      );
    }

    // 4. Completed / Skipped / Failed
    if (status.isCompleted && task.completedAt != null) {
      events.add(
        _TimelineEvent(
          title: 'Task Completed',
          time: task.completedAt.formattedFullDateTime(),
          actor: task.completedBy != null && task.completedBy!.isNotEmpty
              ? 'By ${task.completedBy}'
              : '',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF10B981),
        ),
      );
    } else if (status.isSkipped && task.skippedAt != null) {
      events.add(
        _TimelineEvent(
          title: 'Task Skipped',
          time: task.skippedAt.formattedFullDateTime(),
          actor: task.skippedBy != null && task.skippedBy!.isNotEmpty
              ? 'By ${task.skippedBy}'
              : '',
          icon: Icons.skip_next_outlined,
          color: const Color(0xFFEA580C),
        ),
      );
    } else if (status.isFailed && task.failedAt != null) {
      events.add(
        _TimelineEvent(
          title: 'Task Failed',
          time: task.failedAt.formattedFullDateTime(),
          actor: task.failedBy != null && task.failedBy!.isNotEmpty
              ? 'By ${task.failedBy}'
              : '',
          icon: Icons.cancel_outlined,
          color: const Color(0xFFDC2626),
        ),
      );
    }

    if (events.isEmpty) return const SizedBox.shrink();

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline_rounded, size: 22),
                SizedBox(width: 8),
                Text(
                  'Task Activity Timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ev = events[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ev.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ev.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(ev.icon, size: 16, color: ev.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: ev.color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ev.time,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (ev.actor.isNotEmpty)
                            Text(
                              ev.actor,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 9. Bottom Action Bar
  // ---------------------------------------------------------
  Widget _buildBottomActionBar(CleaningTask task, ThemeData theme) {
    final prov = context.read<FacilityProvider>();
    final isPending = task.taskStatus.isPending;
    final isInProgress = task.taskStatus.isInProgress;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (isPending) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    foregroundColor: const Color(0xFFEA580C),
                    side: const BorderSide(color: Color(0xFFFDBA74)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (_) => SkipCleaningTaskDialog(
                        taskId: task.id ?? widget.taskId,
                        taskName: task.scheduleName ?? '',
                        onConfirm: (reason) async {
                          await prov.skipCleaningTask(
                            taskId: task.id ?? widget.taskId,
                            remarks: reason,
                            context: context,
                          );
                        },
                      ),
                    );
                    if (result == true && mounted) {
                      _loadTaskDetails();
                    }
                  },
                  child: const Text(
                    'Skip Task',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'Start Task',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    await prov.startCleaningTask(
                      task.id ?? widget.taskId,
                      context: context,
                    );
                    _loadTaskDetails();
                  },
                ),
              ),
            ] else if (isInProgress) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (_) => FailCleaningTaskDialog(
                        taskId: task.id ?? widget.taskId,
                        taskName: task.scheduleName ?? '',
                        onConfirm: (reason) async {
                          await prov.failCleaningTask(
                            taskId: task.id ?? widget.taskId,
                            remarks: reason,
                            context: context,
                          );
                        },
                      ),
                    );
                    if (result == true && mounted) {
                      _loadTaskDetails();
                    }
                  },
                  child: const Text(
                    'Report Fail',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'Complete Task',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _handleCompleteTask(task),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineEvent {
  const _TimelineEvent({
    required this.title,
    required this.time,
    required this.actor,
    required this.icon,
    required this.color,
  });

  final String title;
  final String time;
  final String actor;
  final IconData icon;
  final Color color;
}
