import 'dart:convert';

import 'package:face_enrollment/src/models/student_embedding.dart';
import 'package:injectable/injectable.dart';
import 'package:local_storage/local_storage.dart';

/// Device-local cache of student embeddings (Hive), keyed by student id. It holds one
/// login's branch only: [clear] runs on logout.
@lazySingleton
class EmbeddingStore {
  EmbeddingStore(this._storage);

  // v2: embeddings from the eye-order fix; v1 faces were aligned upside down.
  static const _box = 'studentEmbeddings-v1';

  final StorageService _storage;

  Future<void> init() => _storage.openBox<String>(_box);

  Future<void> save(StudentEmbedding embedding) => _storage.put<String>(
    _box,
    embedding.studentId,
    jsonEncode(embedding.toJson()),
  );

  Future<void> saveAll(List<StudentEmbedding> embeddings) =>
      _storage.putAll<String>(_box, {
        for (final e in embeddings) e.studentId: jsonEncode(e.toJson()),
      });

  StudentEmbedding? get(int studentId) {
    final raw = _storage.get<String>(_box, studentId);
    if (raw == null || raw.isEmpty) return null;
    return StudentEmbedding.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  bool has(int studentId) => _storage.containsKey(_box, studentId);

  List<StudentEmbedding> getAll() => [
    for (final raw in _storage.getAll<String>(_box))
      if (raw.isNotEmpty)
        StudentEmbedding.fromJson(jsonDecode(raw) as Map<String, dynamic>),
  ];

  Future<void> clear() => _storage.clearBox(_box);
}
