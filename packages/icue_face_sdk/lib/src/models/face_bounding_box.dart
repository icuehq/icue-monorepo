class FaceBoundingBox {
  const FaceBoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.trackingId,
  });

  factory FaceBoundingBox.fromMap(Map<Object?, Object?> map) {
    return FaceBoundingBox(
      left: (map['left'] as num? ?? 0).toDouble(),
      top: (map['top'] as num? ?? 0).toDouble(),
      right: (map['right'] as num? ?? 0).toDouble(),
      bottom: (map['bottom'] as num? ?? 0).toDouble(),
      trackingId: (map['trackingId'] as num?)?.toInt(),
    );
  }

  final double left;
  final double top;
  final double right;
  final double bottom;
  final int? trackingId;

  Map<String, Object?> toMap() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
    'trackingId': trackingId,
  };

  double get width => right - left;
  double get height => bottom - top;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceBoundingBox &&
          other.left == left &&
          other.top == top &&
          other.right == right &&
          other.bottom == bottom &&
          other.trackingId == trackingId;

  @override
  int get hashCode => Object.hash(left, top, right, bottom, trackingId);
}
