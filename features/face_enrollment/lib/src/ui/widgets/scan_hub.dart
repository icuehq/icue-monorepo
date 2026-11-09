import 'package:core_ui/core_ui.dart';
import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:face_enrollment/src/ui/widgets/glass_card.dart';
import 'package:face_enrollment/src/ui/widgets/identify_results.dart';
import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:image_picker/image_picker.dart';

class ScanHub extends StatelessWidget {
  const ScanHub({
    required this.isScanning,
    required this.attendanceResult,
    required this.identifiedStudents,
    required this.onLiveAttendance,
    required this.onMultiPhoto,
    required this.onSinglePhoto,
    super.key,
  });

  final bool isScanning;
  final AttendanceResult? attendanceResult;
  final List<Student> identifiedStudents;
  final VoidCallback onLiveAttendance;
  final VoidCallback onMultiPhoto;
  final void Function(ImageSource source) onSinglePhoto;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Icon(
                Icons.center_focus_weak_rounded,
                size: 16,
                color: context.scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'AI SCANNING MODES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: context.scheme.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Primary Scan Modes Grid (Live Sweep & Group Photo)
          Row(
            children: [
              Expanded(
                child: _buildScanModeOptionCard(
                  context,
                  title: 'Live Camera Sweep',
                  subtitle: 'Real-time video attendance across classroom',
                  badge: 'AUTOMATED',
                  icon: Icons.videocam_rounded,
                  iconColor: context.scheme.primary,
                  onTap: isScanning ? null : onLiveAttendance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScanModeOptionCard(
                  context,
                  title: 'Group Photo Scan',
                  subtitle: 'Multi-photo group shots with batch detection',
                  badge: 'MULTI-FACE',
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  onTap: isScanning ? null : onMultiPhoto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Single Photo Option
          _buildSinglePhotoOptionCard(context),
          const SizedBox(height: 20),

          // Active Scanning Viewfinder or Results Section
          if (isScanning)
            _buildActiveScanningBanner(context)
          else if (attendanceResult != null) ...[
            IdentifyResultsHeader(
              attendanceResult: attendanceResult!,
              identifiedStudents: identifiedStudents,
            ),
            const SizedBox(height: 14),
            IdentifiedStudentsList(
              attendanceResult: attendanceResult!,
              identifiedStudents: identifiedStudents,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanModeOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          borderColor: iconColor.withValues(alpha: 0.25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: iconColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: context.scheme.onSurface,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: context.scheme.onSurface.withValues(alpha: 0.55),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSinglePhotoOptionCard(BuildContext context) {
    const Color cardColor = Color(0xFF10B981);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      borderColor: cardColor.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.center_focus_strong_rounded,
                  color: cardColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Single Photo Identification',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: context.scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Capture or pick an individual photo to identify faces',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Camera',
                  onPressed: isScanning
                      ? null
                      : () => onSinglePhoto(ImageSource.camera),
                  variant: AppButtonVariant.outline,
                  leadingIcon: Icons.camera_alt_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Gallery',
                  onPressed: isScanning
                      ? null
                      : () => onSinglePhoto(ImageSource.gallery),
                  variant: AppButtonVariant.outline,
                  leadingIcon: Icons.photo_library_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveScanningBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.scheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Analyzing Facial Vector Embeddings...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Running high-precision AI matching against local roster cache',
              style: TextStyle(
                fontSize: 11.5,
                color: context.scheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
