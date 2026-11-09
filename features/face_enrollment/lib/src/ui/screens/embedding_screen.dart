import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/providers/embedding_provider.dart';
import 'package:face_enrollment/src/providers/student_provider.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:face_enrollment/src/ui/widgets/ambient_background.dart';
import 'package:face_enrollment/src/ui/widgets/biometric_scanner_view.dart';
import 'package:face_enrollment/src/ui/widgets/custom_button.dart';
import 'package:face_enrollment/src/ui/widgets/student_header_card.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class EmbeddingScreen extends StatefulWidget {
  const EmbeddingScreen({super.key, required this.student});
  final Student student;

  @override
  State<EmbeddingScreen> createState() => _EmbeddingScreenState();
}

class _EmbeddingScreenState extends State<EmbeddingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  late EmbeddingProvider _embeddingProvider;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _embeddingProvider = Provider.of<EmbeddingProvider>(context, listen: false);
    _embeddingProvider.addListener(_onEmbeddingProviderChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _embeddingProvider.resetState();
      _downloadPhoto();
    });
  }

  void _downloadPhoto() {
    _embeddingProvider
        .downloadStudentPhoto(
          photoUrl: widget.student.photoUrl,
          studentId: widget.student.id,
        )
        .catchError((Object error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: context.scheme.error,
                content: Text('Failed to download student photo: $error'),
              ),
            );
          }
        });
  }

  @override
  void dispose() {
    _embeddingProvider.removeListener(_onEmbeddingProviderChanged);
    _scanController.dispose();
    super.dispose();
  }

  void _onEmbeddingProviderChanged() {
    if (_embeddingProvider.isScanning) {
      if (!_scanController.isAnimating) {
        _scanController.repeat(reverse: true);
      }
    } else {
      if (_scanController.isAnimating) {
        _scanController.stop();
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      await _embeddingProvider.pickImage(source);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.scheme.error,
            content: Text('Failed to select image: $error'),
          ),
        );
      }
    }
  }

  Future<void> _triggerScan() async {
    try {
      await _embeddingProvider.triggerScan();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.scheme.error,
            content: Text(error.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _handleUpload(StudentProvider studentProvider) async {
    final embedding = _embeddingProvider.generatedEmbedding;
    if (embedding == null) return;

    final success = await studentProvider.uploadStudentEmbedding(
      studentId: widget.student.id,
      name: widget.student.name,
      admissionNumber: widget.student.admissionNumber,
      standard: widget.student.standard,
      section: widget.student.section,
      embedding: embedding,
    );

    if (mounted) {
      if (success) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: context.scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF10B981),
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  'Enrollment Complete',
                  style: TextStyle(
                    color: context.scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            content: Text(
              'Biometric embeddings for ${widget.student.name} were successfully stored in local cache & uploaded to server!',
              style: TextStyle(
                color: context.scheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            actions: [
              SizedBox(
                width: 90,
                child: CustomButton(
                  text: 'DONE',
                  height: 38,
                  borderRadius: 10,
                  fontSize: 12.5,
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      } else {
        final error =
            studentProvider.embeddingUploadError ?? 'Unknown error occurred';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.scheme.error,
            content: Text('Failed to update embeddings: $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = Provider.of<StudentProvider>(context);
    final embeddingProvider = Provider.of<EmbeddingProvider>(context);
    final size = MediaQuery.of(context).size;
    final isAlreadyEnrolled = studentProvider.hasEmbedding(widget.student.id);

    return Scaffold(
      backgroundColor: context.scheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: context.scheme.surface,
        surfaceTintColor: context.scheme.surfaceTint,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
          tooltip: 'Back to Directory',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Biometric Enrollment',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: context.scheme.onSurface,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${widget.student.name} • STD ${widget.student.standard}-${widget.student.section}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: context.scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color:
                  (embeddingProvider.generatedEmbedding != null ||
                              isAlreadyEnrolled
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    (embeddingProvider.generatedEmbedding != null ||
                                isAlreadyEnrolled
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  embeddingProvider.generatedEmbedding != null
                      ? Icons.check_circle_rounded
                      : (isAlreadyEnrolled
                            ? Icons.verified_rounded
                            : Icons.hourglass_top_rounded),
                  size: 11,
                  color:
                      embeddingProvider.generatedEmbedding != null ||
                          isAlreadyEnrolled
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 4),
                Text(
                  embeddingProvider.generatedEmbedding != null
                      ? 'Vector Ready'
                      : (isAlreadyEnrolled ? 'Enrolled' : 'Pending'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color:
                        embeddingProvider.generatedEmbedding != null ||
                            isAlreadyEnrolled
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: context.scheme.onSurface.withValues(alpha: 0.07),
          ),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Student Profile Card
                StudentHeaderCard(
                  student: widget.student,
                  embeddingProvider: embeddingProvider,
                ),
                const SizedBox(height: 16),

                // Biometric Camera Viewfinder Section
                Center(
                  child: Column(
                    children: [
                      BiometricScannerView(
                        localImagePath: embeddingProvider.localImagePath,
                        photoUrl: widget.student.photoUrl,
                        imageSource: embeddingProvider.imageSource,
                        isScanning: embeddingProvider.isScanning,
                        scanAnimation: _scanAnimation,
                        size: (size.width * 0.65).clamp(200.0, 260.0),
                      ),
                      const SizedBox(height: 12),

                      // Status Badge Text
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _resolveStatusColor(embeddingProvider)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _resolveStatusColor(embeddingProvider)
                                .withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (embeddingProvider.isScanning) ...[
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    context.scheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ] else if (embeddingProvider.generatedEmbedding !=
                                null) ...[
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                embeddingProvider.scanStatusText,
                                style: TextStyle(
                                  color: _resolveStatusColor(embeddingProvider),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Photo Source Selector Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            embeddingProvider.isScanning ||
                                embeddingProvider.isDownloading
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Camera'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            embeddingProvider.isScanning ||
                                embeddingProvider.isDownloading
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 16,
                        ),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (embeddingProvider.imageSource != 'Server URL' &&
                        widget.student.photoUrl != null &&
                        widget.student.photoUrl!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Reset to Server Photo',
                        child: IconButton.outlined(
                          onPressed:
                              embeddingProvider.isScanning ||
                                  embeddingProvider.isDownloading
                              ? null
                              : _downloadPhoto,
                          icon: const Icon(Icons.restore_rounded, size: 18),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Primary Action Button Flow
                if (embeddingProvider.generatedEmbedding == null) ...[
                  CustomButton(
                    text: embeddingProvider.isScanning
                        ? 'EXTRACTING 192-D VECTOR...'
                        : 'GENERATE EMBEDDING',
                    isLoading: embeddingProvider.isScanning,
                    onPressed:
                        embeddingProvider.isScanning ||
                            embeddingProvider.isDownloading
                        ? null
                        : _triggerScan,
                    icon: Icons.face_unlock_rounded,
                  ),
                ] else ...[
                  CustomButton(
                    text: 'UPLOAD EMBEDDING TO SERVER',
                    isLoading: studentProvider.isUploadingEmbedding,
                    onPressed: () => _handleUpload(studentProvider),
                    icon: Icons.cloud_upload_outlined,
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    text: 'Re-generate Vector',
                    height: 40,
                    isOutlined: true,
                    fontSize: 12.5,
                    icon: Icons.refresh_rounded,
                    onPressed:
                        embeddingProvider.isScanning ||
                            studentProvider.isUploadingEmbedding
                        ? null
                        : _triggerScan,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _resolveStatusColor(EmbeddingProvider provider) {
    if (provider.isScanning) {
      return context.scheme.primary;
    }
    if (provider.generatedEmbedding != null) {
      return const Color(0xFF10B981);
    }
    if (provider.isDownloading) {
      return const Color(0xFF8B5CF6);
    }
    return context.scheme.onSurface.withValues(alpha: 0.65);
  }
}
