import 'face_sdk_accelerator.dart';

class FaceSdkConfig {
  const FaceSdkConfig({
    this.accelerator = FaceSdkAccelerator.cpu,
    this.numThreads,
  }) : assert(
         numThreads == null || (numThreads >= 1 && numThreads <= 8),
         'numThreads must be between 1 and 8',
       );

  /// The only accelerator LiteRT will use to compile the model.
  ///
  /// Initialization fails when the selected accelerator cannot compile the
  /// model; the SDK does not silently fall back to another runtime.
  final FaceSdkAccelerator accelerator;

  /// CPU worker count. Ignored for GPU and NPU execution.
  final int? numThreads;

  Map<String, Object> toMap() {
    final threads = numThreads;
    if (threads != null && (threads < 1 || threads > 8)) {
      throw ArgumentError.value(
        threads,
        'numThreads',
        'Must be between 1 and 8',
      );
    }
    return <String, Object>{
      'accelerator': accelerator.nativeValue,
      'numThreads': ?threads,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceSdkConfig &&
          other.accelerator == accelerator &&
          other.numThreads == numThreads;

  @override
  int get hashCode => Object.hash(accelerator, numThreads);
}
