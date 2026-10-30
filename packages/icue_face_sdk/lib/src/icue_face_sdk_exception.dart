class IcueFaceSdkException implements Exception {
  const IcueFaceSdkException(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Object? details;

  bool get isFrameBusy => code == 'FRAME_BUSY';

  @override
  String toString() => 'IcueFaceSdkException($code, $message)';
}
