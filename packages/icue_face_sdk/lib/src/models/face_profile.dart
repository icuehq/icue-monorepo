import 'package:flutter/foundation.dart';

import 'sdk_constants.dart';

class FaceProfile {
  FaceProfile({
    required this.personId,
    required List<double> embedding,
    this.name,
  }) : embedding = Float32List.fromList(embedding) {
    if (personId.trim().isEmpty) {
      throw ArgumentError.value(personId, 'personId', 'Cannot be blank');
    }
    if (embedding.length != faceEmbeddingSize) {
      throw ArgumentError.value(
        embedding.length,
        'embedding',
        'Must contain exactly $faceEmbeddingSize values',
      );
    }
    if (embedding.any((value) => !value.isFinite)) {
      throw ArgumentError.value(
        embedding,
        'embedding',
        'Values must be finite',
      );
    }
  }

  final String personId;

  /// Shown on the camera overlay instead of [personId] when present.
  final String? name;
  final Float32List embedding;

  Map<String, Object> toMap() => <String, Object>{
    'personId': personId,
    'embedding': embedding,
    'name': ?name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceProfile &&
          other.personId == personId &&
          other.name == name &&
          listEquals(other.embedding, embedding);

  @override
  int get hashCode => Object.hash(personId, name, Object.hashAll(embedding));
}
