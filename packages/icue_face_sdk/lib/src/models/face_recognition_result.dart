import 'face_bounding_box.dart';

class FaceRecognitionResult {
  const FaceRecognitionResult({
    required this.personId,
    required this.score,
    required this.matched,
    required this.boundingBox,
    this.name,
    this.label,
  });

  factory FaceRecognitionResult.fromMap(Map<Object?, Object?> map) {
    final rawBox = map['boundingBox'];
    return FaceRecognitionResult(
      personId: map['personId'] as String?,
      score: (map['score'] as num? ?? 0.0).toDouble(),
      matched: map['matched'] as bool? ?? false,
      boundingBox: FaceBoundingBox.fromMap(
        rawBox is Map
            ? Map<Object?, Object?>.from(rawBox)
            : const <Object?, Object?>{},
      ),
      name: map['name'] as String?,
      label: map['label'] as String?,
    );
  }

  final String? personId;
  final String? name;
  final String? label;
  final double score;
  final bool matched;
  final FaceBoundingBox boundingBox;

  /// Returns the display label: [label] ?? [name] ?? [personId].
  String? get effectiveLabel => label ?? name ?? personId;

  Map<String, Object?> toMap() => <String, Object?>{
    'personId': personId,
    if (name != null) 'name': name,
    if (label != null) 'label': label,
    'score': score,
    'matched': matched,
    'boundingBox': boundingBox.toMap(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceRecognitionResult &&
          other.personId == personId &&
          other.name == name &&
          other.label == label &&
          other.score == score &&
          other.matched == matched &&
          other.boundingBox == boundingBox;

  @override
  int get hashCode => Object.hash(personId, name, label, score, matched, boundingBox);
}
