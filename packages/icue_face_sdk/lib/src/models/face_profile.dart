import 'package:flutter/foundation.dart';

import 'sdk_constants.dart';

class FaceProfile {
  FaceProfile({required this.personId, required List<double> embedding})
    : embedding = Float32List.fromList(embedding) {
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
  final Float32List embedding;

  Map<String, Object> toMap() => <String, Object>{
    'personId': personId,
    'embedding': embedding,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceProfile &&
          other.personId == personId &&
          listEquals(other.embedding, embedding);

  @override
  int get hashCode => Object.hash(personId, Object.hashAll(embedding));
}
