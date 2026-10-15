// ignore_for_file: use_null_aware_elements

import 'package:flutter/foundation.dart';

import 'sdk_constants.dart';

class FaceProfile {
  FaceProfile({
    required this.personId,
    required List<double> embedding,
    this.name,
    this.label,
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
  final String? name;
  final String? label;
  final Float32List embedding;

  /// Returns the display label: [label] ?? [name] ?? [personId].
  String get effectiveLabel => label ?? name ?? personId;

  Map<String, Object> toMap() => <String, Object>{
    'personId': personId,
    'embedding': embedding,
    if (name != null) 'name': name!,
    if (label != null) 'label': label!,
  };

  FaceProfile copyWith({
    String? personId,
    List<double>? embedding,
    String? name,
    String? label,
  }) {
    return FaceProfile(
      personId: personId ?? this.personId,
      embedding: embedding ?? this.embedding,
      name: name ?? this.name,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceProfile &&
          other.personId == personId &&
          other.name == name &&
          other.label == label &&
          listEquals(other.embedding, embedding);

  @override
  int get hashCode => Object.hash(personId, name, label, Object.hashAll(embedding));
}
