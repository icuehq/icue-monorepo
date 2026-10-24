import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models/student_model.dart';
import '../../providers/embedding_provider.dart';
import '../../providers/student_provider.dart';
import '../widgets/ambient_background.dart';
import '../widgets/biometric_scanner_view.dart';
import '../widgets/custom_badge.dart';
import '../widgets/custom_button.dart';
import '../widgets/glass_card.dart';

class EmbeddingScreen extends StatefulWidget {
  final Student student;

  const EmbeddingScreen({super.key, required this.student});

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
    // Laser scan animation
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    // Initialize provider and add listener for scanner animation
    _embeddingProvider = Provider.of<EmbeddingProvider>(context, listen: false);
    _embeddingProvider.addListener(_onEmbeddingProviderChanged);

    // Download remote student photo if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _embeddingProvider.resetState();
      _embeddingProvider
          .downloadStudentPhoto(
            photoUrl: widget.student.photoUrl,
            studentId: widget.student.id,
          )
          .catchError((e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFFF2A54),
                  content: Text('Failed to download student photo: $e'),
                ),
              );
            }
          });
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF2A54),
            content: Text('Failed to select image: $e'),
          ),
        );
      }
    }
  }

  void _triggerScan() async {
    try {
      await _embeddingProvider.triggerScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF2A54),
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  void _handleUpload(StudentProvider studentProvider) async {
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
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF15102A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF00E676), width: 1),
            ),
            title: Row(
              children: const [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF00E676),
                  size: 28,
                ),
                SizedBox(width: 8),
                Text(
                  'Enrollment Complete',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: Text(
              'Biometric embeddings for ${widget.student.name} uploaded successfully to local storage & server!',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              SizedBox(
                width: 90,
                child: CustomButton(
                  text: 'DONE',
                  height: 38,
                  borderRadius: 10,
                  fontSize: 13,
                  onPressed: () {
                    Navigator.pop(dialogContext); // Close dialog
                    Navigator.pop(context); // Go back to student list
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
            backgroundColor: const Color(0xFFFF2A54),
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Student Profile Information Header Card
                      _buildStudentHeaderCard(),
                      const SizedBox(height: 20),

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
                              size: (size.width * 0.7).clamp(220.0, 300.0),
                            ),
                            const SizedBox(height: 14),

                            // Status message badge text
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (embeddingProvider.isScanning
                                            ? const Color(0xFF6C63FF)
                                            : (embeddingProvider
                                                          .generatedEmbedding !=
                                                      null
                                                  ? const Color(0xFF00E676)
                                                  : Colors.white24))
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      (embeddingProvider.isScanning
                                              ? const Color(0xFF6C63FF)
                                              : (embeddingProvider
                                                            .generatedEmbedding !=
                                                        null
                                                    ? const Color(0xFF00E676)
                                                    : Colors.white24))
                                          .withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                embeddingProvider.scanStatusText,
                                style: TextStyle(
                                  color: embeddingProvider.isScanning
                                      ? const Color(0xFF8C85FF)
                                      : (embeddingProvider.generatedEmbedding !=
                                                null
                                            ? const Color(0xFF00E676)
                                            : Colors.white70),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            if (embeddingProvider.imageSource != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Source: ${embeddingProvider.imageSource}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Trigger Buttons
                      CustomButton(
                        text: embeddingProvider.isScanning
                            ? 'EXTRACTING EMBEDDING...'
                            : (embeddingProvider.generatedEmbedding == null
                                  ? 'GENERATE EMBEDDING'
                                  : 'RE-GENERATE EMBEDDING'),
                        onPressed:
                            embeddingProvider.isScanning ||
                                embeddingProvider.isDownloading
                            ? null
                            : _triggerScan,
                        icon: Icons.face_unlock_rounded,
                        gradientColors: const [
                          Color(0xFF6C63FF),
                          Color(0xFF4A00E0),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: 'CAMERA',
                              icon: Icons.camera_alt_outlined,
                              isOutlined: true,
                              height: 44,
                              fontSize: 12,
                              onPressed:
                                  embeddingProvider.isScanning ||
                                      embeddingProvider.isDownloading
                                  ? null
                                  : () => _pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomButton(
                              text: 'GALLERY',
                              icon: Icons.photo_library_outlined,
                              isOutlined: true,
                              height: 44,
                              fontSize: 12,
                              onPressed:
                                  embeddingProvider.isScanning ||
                                      embeddingProvider.isDownloading
                                  ? null
                                  : () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Upload Embeddings Button
                      if (embeddingProvider.generatedEmbedding != null) ...[
                        const SizedBox(height: 12),
                        CustomButton(
                          text: 'UPLOAD EMBEDDINGS',
                          isLoading: studentProvider.isUploadingEmbedding,
                          onPressed: () => _handleUpload(studentProvider),
                          icon: Icons.cloud_upload_outlined,
                          gradientColors: const [
                            Color(0xFF00C6FF),
                            Color(0xFF0072FF),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  padding: const EdgeInsets.all(7),
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'BIOMETRIC ENROLLMENT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8C85FF),
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    'Register student facial vector embeddings',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
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

  Widget _buildStudentHeaderCard() {
    final initials = widget.student.name
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .join();

    final hasPhoto =
        (widget.student.photoUrl != null &&
            widget.student.photoUrl!.isNotEmpty) ||
        ((_embeddingProvider.imageSource == 'Camera' ||
                _embeddingProvider.imageSource == 'Gallery') &&
            _embeddingProvider.localImagePath != null);

    final avatarBorderColor = hasPhoto
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFF2A54);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      bgColor: const Color(0x180F0C20),
      bordercolor: const Color(0x336C63FF),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: avatarBorderColor.withValues(alpha: 0.8),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: avatarBorderColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child:
                  (_embeddingProvider.imageSource == 'Camera' ||
                          _embeddingProvider.imageSource == 'Gallery') &&
                      _embeddingProvider.localImagePath != null
                  ? Image.file(
                      File(_embeddingProvider.localImagePath!),
                      fit: BoxFit.cover,
                    )
                  : (widget.student.photoUrl != null &&
                            widget.student.photoUrl!.isNotEmpty
                        ? Image.network(
                            widget.student.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: const Color(0xFF15102A),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials.length > 2
                                        ? initials.substring(0, 2)
                                        : initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                          )
                        : Container(
                            color: const Color(0xFF15102A),
                            alignment: Alignment.center,
                            child: Text(
                              initials.length > 2
                                  ? initials.substring(0, 2)
                                  : initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'ADM NO: ${widget.student.admissionNumber}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CustomBadge(
                      label:
                          'CLASS ${widget.student.standard}-${widget.student.section}',
                      borderColor: const Color(
                        0xFF6C63FF,
                      ).withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
