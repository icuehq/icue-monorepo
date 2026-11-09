import 'dart:io';

import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/models/student_embedding.dart';
import 'package:face_enrollment/src/providers/batch_progress.dart';
import 'package:face_enrollment/src/services/student_service.dart';
import 'package:face_enrollment/src/storage/embedding_store.dart';
import 'package:face_enrollment/src/utils/error_message.dart';
import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:injectable/injectable.dart';

@injectable
class StudentProvider extends ChangeNotifier {
  StudentProvider(this._studentService, this._embeddingStore, this._faceSdk);
  final StudentService _studentService;
  final EmbeddingStore _embeddingStore;
  final IcueFaceSdk _faceSdk;

  // Pagination states
  int? _classId;
  int? get classId => _classId;

  List<Standard> _standards = [];
  List<Standard> get standards => _standards;

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
    final query = _searchQuery.toLowerCase();
    return _students
        .where(
          (student) =>
              student.name.toLowerCase().contains(query) ||
              student.admissionNumber.toLowerCase().contains(query) ||
              student.standard.toLowerCase().contains(query) ||
              student.section.toLowerCase().contains(query),
        )
        .toList();
  }

  bool hasEmbedding(int studentId) => _embeddingStore.has(studentId);

  int get enrolledCount =>
      _students.where((student) => _embeddingStore.has(student.id)).length;

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

  // Batch processing
  static const _downloadAhead = 3;
  static const _uploadChunkSize = 25;
  static const _maxAttempts = 3;
  static const _retryDelay = Duration(milliseconds: 500);

  final BatchProgress batch = BatchProgress();

  /// Loads every remaining page, so the batch is not limited to what the
  /// user has scrolled to.
  Future<void> _loadAllStudents() async {
    while (_hasMore && !batch.cancelRequested) {
      if (_isLoading || _isLoadingMore) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      batch.say('Loading students (${_students.length}/$_totalStudents)...');
      await fetchStudents();
      if (_errorMessage != null) throw Exception(_errorMessage);
    }
  }

  Future<void> generateAndUploadBatchEmbeddings() async {
    if (batch.isRunning) return;
    final classId = _classId;
    if (classId == null) return;

    batch.begin('Loading students...');
    try {
      await _loadAllStudents();
      final targetStudents = filteredStudents
          .where((s) => s.photoUrl != null && s.photoUrl!.isNotEmpty)
          .toList();
      batch.setTotal(targetStudents.length);

      var pending = targetStudents
          .where((s) => !_embeddingStore.has(s.id))
          .toList();
      batch.record(succeeded: targetStudents.length - pending.length);

      if (pending.isNotEmpty) {
        // Another device may already have uploaded these.
        batch.say('Checking server for existing embeddings...');
        try {
          await _pullEmbeddings(studentIds: [for (final s in pending) s.id]);
        } catch (e) {
          debugPrint('Server embedding check failed: $e');
        }
        final stillPending = pending
            .where((s) => !_embeddingStore.has(s.id))
            .toList();
        batch.record(succeeded: pending.length - stillPending.length);
        pending = stillPending;
      }

      await _generateAndUpload(pending, classId);
    } catch (e) {
      batch.finish('Batch failed: ${describeError(e)}');
    }
  }

  Future<void> _generateAndUpload(List<Student> pending, int classId) async {
    final downloads = <int, Future<({String? path, Object? error})>>{};
    final failures = <String>[];
    void logFailure(String line) {
      failures.add(line);
      debugPrint('[batch embeddings] FAILED $line');
    }

    var nextDownload = 0;
    final unsent = <StudentEmbedding>[];
    var failedUploads = <StudentEmbedding>[];
    var generated = 0;

    for (var i = 0; i < pending.length && !batch.cancelRequested; i++) {
      // Photos download while the SDK extracts earlier ones.
      while (nextDownload < pending.length &&
          nextDownload < i + _downloadAhead) {
        downloads[nextDownload] = _downloadPhoto(pending[nextDownload]);
        nextDownload++;
      }

      final student = pending[i];
      batch.say('Processing ${student.name} (${i + 1}/${pending.length})...');
      final download = (await downloads.remove(i))!;
      final path = download.path;
      if (path == null) {
        logFailure(
          '${student.name} (id ${student.id}): download failed (${describeError(download.error!)})',
        );
        batch.record(succeeded: 0, failed: 1);
        continue;
      }

      try {
        final studentEmbedding = StudentEmbedding(
          studentId: student.id,
          name: student.name,
          admissionNumber: student.admissionNumber,
          standard: student.standard,
          classId: classId,
          section: student.section,
          embedding: await _extractWithRetry(path),
        );
        await _embeddingStore.save(studentEmbedding);
        unsent.add(studentEmbedding);
        generated++;
        batch.record(succeeded: 1);
      } catch (e) {
        debugPrint('Failed to process student ${student.name}: $e');
        logFailure('${student.name} (id ${student.id}): ${describeError(e)}');
        batch.record(succeeded: 0, failed: 1);
      } finally {
        await _deleteQuietly(path);
      }

      if (unsent.length >= _uploadChunkSize) {
        batch.say('Uploading ${unsent.length} embeddings...');
        failedUploads.addAll(await _uploadInChunks(unsent.toList()));
        unsent.clear();
      }
    }

    for (final download in downloads.values) {
      final path = (await download).path;
      if (path != null) await _deleteQuietly(path);
    }

    // Embeddings are saved locally, so upload whatever is left even when
    // cancelled; otherwise the "already stored" check would skip them forever.
    if (unsent.isNotEmpty || failedUploads.isNotEmpty) {
      batch.say(
        'Uploading ${unsent.length + failedUploads.length} embeddings...',
      );
      failedUploads = await _uploadInChunks([...failedUploads, ...unsent]);
    }

    final cancelled = batch.cancelRequested ? 'Batch cancelled. ' : '';
    final uploaded = generated - failedUploads.length;
    final summary = generated == 0
        ? 'No new embeddings were generated.'
        : 'Generated $generated new embeddings, uploaded $uploaded.';
    final warning = failedUploads.isEmpty
        ? ''
        : ' ${failedUploads.length} could not be uploaded and are only on this device.';
    if (failures.isNotEmpty) {
      debugPrint(
        '[batch embeddings] ${failures.length} failed:\n${failures.join('\n')}',
      );
    }
    final reasons = failures.isEmpty
        ? ''
        : '\nFailed: ${failures.take(5).join('; ')}'
              '${failures.length > 5 ? '; +${failures.length - 5} more' : ''}';
    batch.finish('$cancelled$summary$warning$reasons');
  }

  Future<({String? path, Object? error})> _downloadPhoto(
    Student student,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_retryDelay * attempt);
      try {
        final path = await _studentService.downloadPhoto(
          student.photoUrl!,
          'temp_batch_student_${student.id}_photo.jpg',
        );
        return (path: path, error: null);
      } catch (e) {
        lastError = e;
      }
    }
    return (path: null, error: lastError);
  }

  /// Retries because the native decoder can fail transiently under memory
  /// pressure during a long run, while the same photo succeeds on its own.
  Future<List<double>> _extractWithRetry(String path) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_retryDelay * attempt);
      try {
        return await _faceSdk.extractEmbedding(imagePath: path);
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception(describeError(lastError!));
  }

  /// Returns the embeddings the server did not accept.
  Future<List<StudentEmbedding>> _uploadInChunks(
    List<StudentEmbedding> embeddings,
  ) async {
    final failed = <StudentEmbedding>[];
    for (var i = 0; i < embeddings.length; i += _uploadChunkSize) {
      final chunk = embeddings.sublist(
        i,
        (i + _uploadChunkSize).clamp(0, embeddings.length),
      );
      try {
        if (!await _studentService.updateStuEmbeddings(chunk)) {
          failed.addAll(chunk);
        }
      } catch (e) {
        debugPrint('Embedding upload failed: $e');
        failed.addAll(chunk);
      }
    }
    return failed;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
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

  Future<void> resetAndFetch() {
    _students.clear();
    _currentPage = 1;
    _hasMore = true;
    _errorMessage = null;
    return fetchStudents(isRefresh: true);
  }

  Future<void> fetchStudents({bool isRefresh = false}) async {
    if (_classId == null) {
      return;
    }
    if (isRefresh) {
      _isLoading = true;
    } else {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _studentService.getStudentPhotos(
        classId: _classId!,
        pageNumber: _currentPage,
        pageSize: _pageSize,
        hasPhoto: _studentPhotoFilter,
      );

      if (isRefresh) {
        _students = page.students;
      } else {
        _students.addAll(page.students);
      }

      _totalStudents = page.total;
      _hasMore = page.students.isNotEmpty && _students.length < _totalStudents;
      if (_hasMore) {
        _currentPage++;
      }

      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isLoadingMore = false;
      _errorMessage = describeError(e);
      notifyListeners();
    }
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
    await _embeddingStore.save(studentEmbedding);

    try {
      final success = await _studentService.updateStuEmbeddings([
        studentEmbedding,
      ]);
      _isUploadingEmbedding = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isUploadingEmbedding = false;
      _embeddingUploadError = describeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<List<StudentEmbedding>> _pullEmbeddings({
    List<int>? studentIds,
  }) async {
    // Ensure standards are loaded so we can resolve Standard Name to ClassId
    if (_standards.isEmpty) {
      await fetchStandards();
    }

    final embeddings = await _studentService.getStuEmbeddings(
      studentIds: studentIds,
      classIdFor: (standard) {
        final name = standard.trim().toLowerCase();
        for (final candidate in _standards) {
          if (candidate.name.trim().toLowerCase() == name) {
            return candidate.id;
          }
        }
        return _classId ?? 0;
      },
    );
    await _embeddingStore.saveAll(embeddings);
    return embeddings;
  }

  Future<int> syncEmbeddingsFromServer({List<int>? studentIds}) async {
    _isSyncingEmbeddings = true;
    _syncError = null;
    notifyListeners();

    try {
      final embeddings = await _pullEmbeddings(studentIds: studentIds);
      _isSyncingEmbeddings = false;
      notifyListeners();
      return embeddings.length;
    } catch (e) {
      _isSyncingEmbeddings = false;
      _syncError = describeError(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchStandards() async {
    try {
      _standards = await _studentService.getStandards();
      if (_classId == null && _standards.isNotEmpty) {
        _classId = _standards.first.id;
      }
      notifyListeners();
    } catch (error) {
      debugPrint('[getStandards error]: $error');
    }
  }
}
