import 'face_bounding_box.dart';

class FaceRecognitionResult {
  const FaceRecognitionResult({
    required this.personId,
    required this.score,
    required this.matched,
    required this.boundingBox,
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
    );
  }

  final String? personId;
  final double score;
  final bool matched;
  final FaceBoundingBox boundingBox;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceRecognitionResult &&
          other.personId == personId &&
          other.score == score &&
          other.matched == matched &&
          other.boundingBox == boundingBox;

  @override
  int get hashCode => Object.hash(personId, score, matched, boundingBox);
}
