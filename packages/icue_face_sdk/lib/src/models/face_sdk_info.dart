class FaceSdkInfo {
  const FaceSdkInfo({
    required this.sdkVersion,
    required this.modelName,
    required this.embeddingSize,
  });

  factory FaceSdkInfo.fromMap(Map<Object?, Object?> map) => FaceSdkInfo(
    sdkVersion: map['sdkVersion'] as String? ?? '',
    modelName: map['modelName'] as String? ?? '',
    embeddingSize: (map['embeddingSize'] as num? ?? 0).toInt(),
  );

  final String sdkVersion;
  final String modelName;
  final int embeddingSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceSdkInfo &&
          other.sdkVersion == sdkVersion &&
          other.modelName == modelName &&
          other.embeddingSize == embeddingSize;

  @override
  int get hashCode => Object.hash(sdkVersion, modelName, embeddingSize);
}
