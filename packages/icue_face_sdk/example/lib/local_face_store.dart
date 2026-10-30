import 'dart:convert';

import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FaceEnrollment {
  FaceEnrollment({required String name, required List<double> embedding})
    : _profile = FaceProfile(
        personId: name.trim(),
        embedding: List<double>.unmodifiable(embedding),
      );

  factory FaceEnrollment.fromJson(Map<String, Object?> json) {
    final rawEmbedding = json['embedding'];
    if (rawEmbedding is! List<Object?>) {
      throw const FormatException('Enrollment embedding must be a list');
    }
    return FaceEnrollment(
      name: json['name']! as String,
      embedding: rawEmbedding
          .map((value) => (value! as num).toDouble())
          .toList(),
    );
  }

  final FaceProfile _profile;

  String get name => _profile.personId;
  List<double> get embedding => _profile.embedding;

  FaceProfile toProfile() => _profile;

  Map<String, Object> toJson() => <String, Object>{
    'name': name,
    'embedding': embedding,
  };
}

abstract interface class FaceStore {
  Future<List<FaceEnrollment>> load();

  Future<List<FaceEnrollment>> upsert(
    List<FaceEnrollment> current,
    FaceEnrollment enrollment,
  );

  Future<List<FaceEnrollment>> remove(
    List<FaceEnrollment> current,
    String name,
  );
}

class LocalFaceStore implements FaceStore {
  LocalFaceStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'icue_face_enrollments_v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<FaceEnrollment>> load() async {
    final encoded = await _preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return const <FaceEnrollment>[];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List<Object?>) return const <FaceEnrollment>[];
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map(
            (item) => FaceEnrollment.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
    } on Object {
      return const <FaceEnrollment>[];
    }
  }

  @override
  Future<List<FaceEnrollment>> upsert(
    List<FaceEnrollment> current,
    FaceEnrollment enrollment,
  ) async {
    final normalizedName = enrollment.name.toLowerCase();
    final updated = <FaceEnrollment>[
      for (final item in current)
        if (item.name.toLowerCase() != normalizedName) item,
      enrollment,
    ]..sort((first, second) => first.name.compareTo(second.name));
    await _save(updated);
    return List<FaceEnrollment>.unmodifiable(updated);
  }

  @override
  Future<List<FaceEnrollment>> remove(
    List<FaceEnrollment> current,
    String name,
  ) async {
    final normalizedName = name.toLowerCase();
    final updated = current
        .where((item) => item.name.toLowerCase() != normalizedName)
        .toList(growable: false);
    await _save(updated);
    return List<FaceEnrollment>.unmodifiable(updated);
  }

  Future<void> _save(List<FaceEnrollment> enrollments) =>
      _preferences.setString(
        _storageKey,
        jsonEncode(enrollments.map((item) => item.toJson()).toList()),
      );
}
