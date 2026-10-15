import 'attendance_models.dart';
import 'face_sdk_accelerator.dart';

class FaceSdkConfig {
  const FaceSdkConfig({
    this.accelerator = FaceSdkAccelerator.cpu,
    this.numThreads,
    this.type = AttendanceType.TRANSPORT,
    this.detectedLabelField = DetectedLabelField.ID,
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

  /// Context type: ATTENDANCE or TRANSPORT (defaults to TRANSPORT).
  final AttendanceType type;

  /// Default detected label field to display: ID (default), NAME, LABEL, or NAME_AND_ID.
  final DetectedLabelField detectedLabelField;

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
      'type': type.name,
      'detectedLabelField': detectedLabelField.name,
    };
  }

  FaceSdkConfig copyWith({
    FaceSdkAccelerator? accelerator,
    int? numThreads,
    AttendanceType? type,
    DetectedLabelField? detectedLabelField,
  }) {
    return FaceSdkConfig(
      accelerator: accelerator ?? this.accelerator,
      numThreads: numThreads ?? this.numThreads,
      type: type ?? this.type,
      detectedLabelField: detectedLabelField ?? this.detectedLabelField,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceSdkConfig &&
          other.accelerator == accelerator &&
          other.numThreads == numThreads &&
          other.type == type &&
          other.detectedLabelField == detectedLabelField;

  @override
  int get hashCode => Object.hash(accelerator, numThreads, type, detectedLabelField);
}
