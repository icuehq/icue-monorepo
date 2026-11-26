import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:face_enrollment/src/services/student_service.dart';
import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';

@injectable
class EmbeddingProvider extends ChangeNotifier {
  EmbeddingProvider(this._faceSdk, this._studentService);
  final IcueFaceSdk _faceSdk;
  final StudentService _studentService;

  List<double>? _generatedEmbedding;
  List<double>? get generatedEmbedding => _generatedEmbedding;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  String _scanStatusText = 'Ready to Scan';
  String get scanStatusText => _scanStatusText;

  String? _localImagePath;
  String? get localImagePath => _localImagePath;

  String? _imageSource; // 'Server URL', 'Camera', 'Gallery'
  String? get imageSource => _imageSource;

  // Bumped whenever the screen's student or photo changes, so a download or scan that
  // finishes late can never put one student's face on another student's screen.
  int _request = 0;

  void resetState() {
    _request++;
    _generatedEmbedding = null;
    _isScanning = false;
    _isDownloading = false;
    _scanStatusText = 'Ready to Scan';
    _localImagePath = null;
    _imageSource = null;
    notifyListeners();
  }

  Future<void> downloadStudentPhoto({
    required String? photoUrl,
    required int studentId,
  }) async {
    if (photoUrl == null || photoUrl.isEmpty) {
      _scanStatusText = 'No student photo on server. Use camera/gallery.';
      notifyListeners();
      return;
    }

    final request = ++_request;
    _isDownloading = true;
    _scanStatusText = 'Downloading student photo...';
    notifyListeners();

    try {
      final filePath = await _studentService.downloadPhoto(
        photoUrl,
        'student_${studentId}_photo.jpg',
      );
      if (request != _request) return;

      _localImagePath = filePath;
      _isDownloading = false;
      _imageSource = 'Server URL';
      _scanStatusText = 'Photo downloaded. Ready to extract embedding.';
      notifyListeners();
    } catch (e, stack) {
      if (request != _request) return;
      _isDownloading = false;
      _scanStatusText = 'Download failed. Use camera or gallery.';
      notifyListeners();
      unawaited(
        CrashlyticsService.instance.recordError(
          e,
          stack,
          reason: 'Student photo download failed for student $studentId',
          information: ['photoUrl: $photoUrl'],
        ),
      );
      rethrow;
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        _request++;
        _isDownloading = false;
        _localImagePath = pickedFile.path;
        _imageSource = source == ImageSource.camera ? 'Camera' : 'Gallery';
        _generatedEmbedding = null;
        _scanStatusText = 'Photo loaded. Click SCAN FACE to process.';
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> triggerScan() async {
    if (_isScanning) return;

    if (!Platform.isAndroid && !Platform.isIOS) {
      // Dev mock mode for Web/Desktop/Simulators
      _isScanning = true;
      _generatedEmbedding = null;
      _scanStatusText = 'Running in Dev Mock Mode...';
      notifyListeners();

      await Future<void>.delayed(const Duration(seconds: 2));

      final random = Random();
      final List<double> mockRaw = List.generate(
        192,
        (_) => (random.nextDouble() * 2) - 1.0,
      );
      final double sqNorm = mockRaw.fold(0.0, (s, e) => s + e * e);
      final double norm = sqrt(max(sqNorm, 1e-12));
      final List<double> mockEmbedding = mockRaw.map((e) => e / norm).toList();

      _isScanning = false;
      _generatedEmbedding = mockEmbedding;
      _scanStatusText = 'Biometric signature verified (192-d Mock)!';
      notifyListeners();
      return;
    }

    if (_localImagePath == null) {
      throw Exception('Please capture or choose a photo first.');
    }

    final request = _request;
    _isScanning = true;
    _generatedEmbedding = null;
    _scanStatusText = 'Extracting facial embedding...';
    notifyListeners();

    try {
      final embedding = await _faceSdk.extractEmbedding(
        imagePath: _localImagePath!,
      );
      if (request != _request) return;

      if (embedding.length != 192) {
        throw Exception(
          'Model contract error: Expected 192-d embedding vector, received ${embedding.length}',
        );
      }

      _isScanning = false;
      _generatedEmbedding = embedding;
      _scanStatusText = 'Biometric signature verified!';
      notifyListeners();
    } catch (e, stack) {
      if (request != _request) return;
      _isScanning = false;
      _scanStatusText = 'Extraction failed: $e';
      notifyListeners();
      unawaited(
        CrashlyticsService.instance.recordError(
          e,
          stack,
          reason: 'Face embedding extraction failed for $_localImagePath',
          information: ['imageSource: $_imageSource'],
        ),
      );
      rethrow;
    }
  }
}
