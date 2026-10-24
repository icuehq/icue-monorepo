import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../core/storage/pref_service.dart';
import '../data/models/embedding_request.dart';
import '../data/models/standards_model.dart';
import '../data/models/student_embeddings_response.dart';
import '../data/models/student_model.dart';
import '../data/services/student_service.dart';

@injectable
class StudentProvider extends ChangeNotifier {
  final StudentService _studentService;
  final PrefService _prefService;
  final IcueFaceSdk _faceSdk;

  StudentProvider(this._studentService, this._prefService, this._faceSdk);

  // Pagination states
  int? _classId;
  int? get classId => _classId;

  List<StandardModel> _standards = [];
  List<StandardModel> get standards => _standards;

  int _currentPage = 1;
  int get currentPage => _currentPage;

  final int _pageSize = 100;
  int get pageSize => _pageSize;

  int _totalStudents = 0;
  int get totalStudents => _totalStudents;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Option states
  bool? _studentPhotoFilter =
      true; // Default: show photos (true). Can toggle to false or null.
  bool? get studentPhotoFilter => _studentPhotoFilter;

  // Search state
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Raw fetched students list
  List<Student> _students = [];
  List<Student> get students => _students;

  // Filtered list based on search
  List<Student> get filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    return _students
        .where(
          (s) =>
              s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.admissionNumber.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              s.standard.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.section.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  // Upload embedding states
  bool _isUploadingEmbedding = false;
  bool get isUploadingEmbedding => _isUploadingEmbedding;

  String? _embeddingUploadError;
  String? get embeddingUploadError => _embeddingUploadError;

  // Sync embedding states
  bool _isSyncingEmbeddings = false;
  bool get isSyncingEmbeddings => _isSyncingEmbeddings;

  String? _syncError;
  String? get syncError => _syncError;

  // Batch processing states
  bool _isBatchProcessing = false;
  bool get isBatchProcessing => _isBatchProcessing;

  double _batchProgress = 0.0;
  double get batchProgress => _batchProgress;

  String _batchProgressMessage = '';
  String get batchProgressMessage => _batchProgressMessage;

  int _batchTotalCount = 0;
  int get batchTotalCount => _batchTotalCount;

  int _batchSuccessCount = 0;
  int get batchSuccessCount => _batchSuccessCount;

  int _batchFailureCount = 0;
  int get batchFailureCount => _batchFailureCount;

  bool _cancelBatchRequested = false;
  bool get cancelBatchRequested => _cancelBatchRequested;

  void cancelBatchProcessing() {
    _cancelBatchRequested = true;
    _batchProgressMessage = 'Cancelling batch process...';
    notifyListeners();
  }

  Future<void> generateAndUploadBatchEmbeddings(
    List<Student> targetStudents,
  ) async {
    if (_isBatchProcessing) return;

    _isBatchProcessing = true;
    _batchProgress = 0.0;
    _batchProgressMessage = 'Starting batch process...';
    _batchTotalCount = targetStudents.length;
    _batchSuccessCount = 0;
    _batchFailureCount = 0;
    _cancelBatchRequested = false;
    notifyListeners();

    final List<StudentEmbedding> successfulEmbeddings = [];
    final Dio dio = Dio();

    for (int i = 0; i < targetStudents.length; i++) {
      if (_cancelBatchRequested) {
        _batchProgressMessage = 'Batch process cancelled.';
        break;
      }

      final student = targetStudents[i];
      final currentProgress = i / targetStudents.length;

      // Check if student's embedding is already stored in SharedPreferences
      if (_prefService.hasStudentEmbedding(student.id)) {
        _batchProgressMessage =
            'Embedding for ${student.name} already in prefs. Skipping API upload (${i + 1}/${targetStudents.length})...';
        _batchProgress = (i + 1) / targetStudents.length;
        _batchSuccessCount++;
        notifyListeners();
        continue;
      }

      _batchProgressMessage =
          'Downloading photo for ${student.name} (${i + 1}/${targetStudents.length})...';
      _batchProgress = currentProgress;
      notifyListeners();

      String? tempFilePath;
      try {
        if (student.photoUrl == null || student.photoUrl!.isEmpty) {
          throw Exception('No photo URL');
        }

        final tempDir = await getTemporaryDirectory();
        tempFilePath =
            '${tempDir.path}/temp_batch_student_${student.id}_photo.jpg';
        final file = File(tempFilePath);
        if (await file.exists()) {
          await file.delete();
        }

        await dio.download(student.photoUrl!, tempFilePath);

        if (_cancelBatchRequested) {
          _batchProgressMessage = 'Batch process cancelled.';
          break;
        }

        _batchProgressMessage =
            'Extracting embedding for ${student.name} (${i + 1}/${targetStudents.length})...';
        notifyListeners();

        final embedding = await _faceSdk.extractEmbedding(
          imagePath: tempFilePath,
        );

        final studentEmbedding = StudentEmbedding(
          studentId: student.id,
          name: student.name,
          admissionNumber: student.admissionNumber,
          standard: student.standard,
          classId: _classId!,
          section: student.section,
          embedding: embedding,
        );

        // Store full student embedding info in SharedPreferences
        await _prefService.saveStudentEmbedding(studentEmbedding);

        successfulEmbeddings.add(studentEmbedding);
        _batchSuccessCount++;
      } catch (e) {
        debugPrint('Failed to process student ${student.name}: $e');
        _batchFailureCount++;
      } finally {
        if (tempFilePath != null) {
          try {
            final file = File(tempFilePath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
        }
      }

      _batchProgress = (i + 1) / targetStudents.length;
      notifyListeners();
    }

    if (_cancelBatchRequested) {
      _isBatchProcessing = false;
      notifyListeners();
      return;
    }

    if (successfulEmbeddings.isNotEmpty) {
      _batchProgressMessage =
          'Uploading ${successfulEmbeddings.length} new embeddings to server...';
      notifyListeners();

      final orgId = _prefService.orgId!;
      final zoneId = _prefService.zoneId!;
      final branchId = _prefService.branchId!;

      final request = EmbeddingRequest(
        organizationId: orgId,
        zoneId: zoneId,
        branchId: branchId,
        embeddings: successfulEmbeddings,
      );

      try {
        final success = await _studentService.updateStuEmbeddings(request);
        if (success) {
          _batchProgressMessage =
              'Successfully stored embeddings in prefs and uploaded ${successfulEmbeddings.length} new embeddings to server!';
        } else {
          _batchProgressMessage =
              'Failed to upload embeddings: Server rejected request.';
        }
      } catch (e) {
        _batchProgressMessage =
            'Failed to upload embeddings: ${e.toString().replaceAll('DioException', 'Network Error')}';
      }
    } else {
      _batchProgressMessage =
          'All selected student embeddings are already stored in prefs. No API upload needed.';
    }

    _isBatchProcessing = false;
    notifyListeners();
  }

  void setClassId(int id) {
    _classId = id;
    resetAndFetch();
  }

  void togglePhotoFilter(bool? value) {
    _studentPhotoFilter = value;
    resetAndFetch();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Bumped on every reset so responses from a superseded request are dropped.
  int _requestGen = 0;

  Future<void> resetAndFetch() {
    _students = [];
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;
    _errorMessage = null;
    return fetchStudents(isRefresh: true);
  }

  Future<void> fetchStudents({bool isRefresh = false}) async {
    if (_classId == null) return;
    if (isRefresh) {
      _isLoading = true;
    } else {
      if (!_hasMore || _isLoadingMore || _isLoading) return;
      _isLoadingMore = true;
    }
    final gen = ++_requestGen;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _studentService.getStudentPhotos(
        classId: _classId!,
        pageNumber: _currentPage,
        pageSize: _pageSize,
        studentPhoto: _studentPhotoFilter,
      );
      if (gen != _requestGen) return;

      _students = [..._students, ...response.data];
      _totalStudents = response.metadata.total;
      // An empty page means no more data, even if total says otherwise.
      _hasMore = response.data.isNotEmpty && _students.length < _totalStudents;
      if (_hasMore) {
        _currentPage++;
      }
    } catch (e) {
      if (gen != _requestGen) return;
      _errorMessage = e.toString().replaceAll('DioException', 'Network Error');
    }
    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<bool> uploadStudentEmbedding({
    required int studentId,
    required String name,
    required String admissionNumber,
    required String standard,
    required String section,
    required List<double> embedding,
  }) async {
    _isUploadingEmbedding = true;
    _embeddingUploadError = null;
    notifyListeners();

    final studentEmbedding = StudentEmbedding(
      studentId: studentId,
      name: name,
      admissionNumber: admissionNumber,
      standard: standard,
      classId: _classId!,
      section: section,
      embedding: embedding,
    );

    // Store full student embedding info in SharedPreferences
    await _prefService.saveStudentEmbedding(studentEmbedding);

    final orgId = _prefService.orgId!;
    final zoneId = _prefService.zoneId!;
    final branchId = _prefService.branchId!;

    final request = EmbeddingRequest(
      organizationId: orgId,
      zoneId: zoneId,
      branchId: branchId,
      embeddings: [studentEmbedding],
    );

    try {
      final success = await _studentService.updateStuEmbeddings(request);
      _isUploadingEmbedding = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isUploadingEmbedding = false;
      _embeddingUploadError = e.toString().replaceAll(
        'DioException',
        'Network Error',
      );
      notifyListeners();
      return false;
    }
  }

  Future<int> syncEmbeddingsFromServer({List<int>? studentIds}) async {
    _isSyncingEmbeddings = true;
    _syncError = null;
    notifyListeners();

    try {
      // Ensure standards are loaded so we can resolve Standard Name to ClassId
      if (_standards.isEmpty) {
        await fetchStandards();
      }

      final StudentEmbeddingsResponse response = await _studentService
          .getStuEmbeddings(studentIds: studentIds);
      if (response.err) {
        throw Exception(response.message);
      }

      int syncedCount = 0;
      for (final item in response.data) {
        // Look up standard classId by standard name (e.g. "1")
        int matchedClassId = 0;
        for (final std in _standards) {
          if (std.name.trim().toLowerCase() ==
              item.standard.trim().toLowerCase()) {
            matchedClassId = std.id;
            break;
          }
        }
        // Fallback to selected class ID or 0
        if (matchedClassId == 0 && _classId != null) {
          matchedClassId = _classId!;
        }

        final studentEmbedding = StudentEmbedding(
          studentId: item.studentId,
          name: item.name,
          admissionNumber: item.admissionNumber,
          standard: item.standard,
          classId: matchedClassId,
          section: item.section,
          embedding: item.embedding,
        );

        await _prefService.saveStudentEmbedding(studentEmbedding);
        syncedCount++;
      }

      _isSyncingEmbeddings = false;
      notifyListeners();
      return syncedCount;
    } catch (e) {
      _isSyncingEmbeddings = false;
      _syncError = e.toString().replaceAll('DioException', 'Network Error');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchStandards() async {
    try {
      _standards = await _studentService.getStandards();
      // Without a selected class nothing is ever fetched; default to the first.
      if (_standards.isNotEmpty &&
          !_standards.any((s) => s.id == _classId)) {
        _classId = _standards.first.id;
      }
    } catch (e) {
      debugPrint('[getStandards error]: $e');
      _errorMessage = 'Failed to load classes. Please try again.';
    }
    notifyListeners();
  }
}
