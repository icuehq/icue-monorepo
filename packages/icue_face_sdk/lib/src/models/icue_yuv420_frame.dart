import 'dart:typed_data';

class IcueYuv420Frame {
  const IcueYuv420Frame({
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.width,
    required this.height,
    required this.yRowStride,
    required this.uRowStride,
    required this.vRowStride,
    required this.uPixelStride,
    required this.vPixelStride,
    this.rotationDegrees = 0,
    this.mirrorHorizontally = false,
  });

  final Uint8List yBytes;
  final Uint8List uBytes;
  final Uint8List vBytes;
  final int width;
  final int height;
  final int yRowStride;
  final int uRowStride;
  final int vRowStride;
  final int uPixelStride;
  final int vPixelStride;
  final int rotationDegrees;
  final bool mirrorHorizontally;

  Map<String, Object> toMap() => <String, Object>{
    'yBytes': yBytes,
    'uBytes': uBytes,
    'vBytes': vBytes,
    'width': width,
    'height': height,
    'yRowStride': yRowStride,
    'uRowStride': uRowStride,
    'vRowStride': vRowStride,
    'uPixelStride': uPixelStride,
    'vPixelStride': vPixelStride,
    'rotation': rotationDegrees,
    'isFrontCamera': mirrorHorizontally,
  };
}
