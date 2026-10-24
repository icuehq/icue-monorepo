import 'dart:io';
import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';

import 'custom_button.dart';
import 'glass_card.dart';

/// Modal dialog shown in the consumer app when unknown or unregistered students
/// are detected during facial recognition scanning (e.g., Transport Bus or Class Attendance).
class UnrecognizedStudentDialog extends StatelessWidget {
  final AttendanceType type;
  final List<UnrecognizedFaceRecord> unrecognizedRecords;
  final List<FaceRecognitionResult> liveRecognitions;
  final int totalUnrecognizedCount;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String? actionLabel;

  const UnrecognizedStudentDialog({
    super.key,
    this.type = AttendanceType.TRANSPORT,
    this.unrecognizedRecords = const [],
    this.liveRecognitions = const [],
    this.totalUnrecognizedCount = 0,
    this.onDismiss,
    this.onAction,
    this.actionLabel,
  });

  /// Displays the unrecognized student alert dialog over the current context.
  static Future<void> show({
    required BuildContext context,
    AttendanceType type = AttendanceType.TRANSPORT,
    AttendanceResult? attendanceResult,
    List<UnrecognizedFaceRecord>? unrecognizedFaces,
    List<FaceRecognitionResult>? liveRecognitions,
    int? unrecognizedCount,
    VoidCallback? onDismiss,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final records = unrecognizedFaces ??
        attendanceResult?.unrecognizedFaces ??
        const <UnrecognizedFaceRecord>[];

    final liveRecs = liveRecognitions ?? const <FaceRecognitionResult>[];

    final count = unrecognizedCount ??
        attendanceResult?.unrecognizedFaceCount ??
        (records.isNotEmpty ? records.length : liveRecs.length);

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => UnrecognizedStudentDialog(
        type: type,
        unrecognizedRecords: records,
        liveRecognitions: liveRecs,
        totalUnrecognizedCount: count,
        onDismiss: onDismiss,
        onAction: onAction,
        actionLabel: actionLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTransport = type == AttendanceType.TRANSPORT;
    final primaryColor = isTransport ? const Color(0xFFFFB300) : const Color(0xFFFF2A54);
    final count = totalUnrecognizedCount > 0
        ? totalUnrecognizedCount
        : (unrecognizedRecords.isNotEmpty
            ? unrecognizedRecords.length
            : (liveRecognitions.isNotEmpty ? liveRecognitions.length : 1));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(22),
        borderRadius: 26,
        bgColor: const Color(0xE6130F26),
        bordercolor: primaryColor.withValues(alpha: 0.4),
        blur: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning Icon Badge & Badge Pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    isTransport
                        ? Icons.directions_bus_rounded
                        : Icons.person_off_rounded,
                    color: primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isTransport ? 'BUS TRANSPORT ALERT' : 'ATTENDANCE ALERT',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTransport
                            ? 'Transport Bus Alert'
                            : 'Unregistered Student Detected',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDismiss?.call();
                  },
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Highlighted Alert Message
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTransport
                              ? 'This student does not belong to this Bus.'
                              : 'This student does not belong to this roster.',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isTransport
                              ? '$count unregistered or cross-bus student face(s) identified during the transport scan.'
                              : '$count unrecognized face(s) detected that could not be matched against any registered profile.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Detailed Unrecognized Faces List (if available)
            if (unrecognizedRecords.isNotEmpty || liveRecognitions.isNotEmpty) ...[
              const Text(
                'DETECTED FACE DETAILS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white54,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      if (unrecognizedRecords.isNotEmpty)
                        ...unrecognizedRecords.map((r) => _buildRecordCard(r, primaryColor)),
                      if (unrecognizedRecords.isEmpty && liveRecognitions.isNotEmpty)
                        ...liveRecognitions.map((lr) => _buildLiveRecognitionCard(lr, primaryColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'ACKNOWLEDGE',
                    height: 44,
                    borderRadius: 14,
                    fontSize: 12.5,
                    isOutlined: onAction != null,
                    outlineColor: onAction != null ? primaryColor.withValues(alpha: 0.6) : null,
                    gradientColors: onAction == null
                        ? [primaryColor, const Color(0xFFE65100)]
                        : [const Color(0xFF6C63FF), const Color(0xFF3F3D56)],
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDismiss?.call();
                    },
                  ),
                ),
                if (onAction != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomButton(
                      text: actionLabel ?? 'TAKE ACTION',
                      height: 44,
                      borderRadius: 14,
                      fontSize: 12.5,
                      gradientColors: [primaryColor, const Color(0xFFE65100)],
                      onPressed: () {
                        Navigator.of(context).pop();
                        onAction?.call();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(UnrecognizedFaceRecord record, Color accentColor) {
    final scorePct = (record.confidenceScore * 100).toStringAsFixed(1);
    final timeStr = _formatTimestamp(record.timestamp);
    final box = record.boundingBox;
    final boxStr = box != null
        ? 'Box: [${box.left.toInt()}, ${box.top.toInt()} - ${box.right.toInt()}, ${box.bottom.toInt()}]'
        : 'Face Detected';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Photo thumbnail if path exists, otherwise icon
          if (record.sourceImagePath != null && File(record.sourceImagePath!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(record.sourceImagePath!),
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.face_retouching_off_rounded, color: accentColor, size: 22),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unknown Student Face',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeStr • $boxStr',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              '$scorePct%',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRecognitionCard(FaceRecognitionResult res, Color accentColor) {
    final scorePct = (res.score * 100).toStringAsFixed(1);
    final box = res.boundingBox;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.face_retouching_off_rounded, color: accentColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Real-Time Live Face',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Box: [${box.left.toInt()}, ${box.top.toInt()} - ${box.right.toInt()}, ${box.bottom.toInt()}]',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              '$scorePct%',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
