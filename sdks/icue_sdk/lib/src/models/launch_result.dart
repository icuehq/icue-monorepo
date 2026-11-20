import 'package:flutter/foundation.dart';

/// Base exception for all iCue SDK operational errors.
abstract class IcueException implements Exception {
  const IcueException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when attempting an operation that requires `IcueSdk.init` before
/// configuration has been supplied.
class IcueNotInitializedException extends IcueException {
  const IcueNotInitializedException([
    super.message =
        'iCue SDK is not initialized. Await IcueSdk.init(config) before opening tracking or accessing features.',
  ]);
}

/// Thrown when an invalid or empty student identification number is provided.
class IcueInvalidStudentException extends IcueException {
  const IcueInvalidStudentException([
    super.message = 'Invalid or empty student identification number provided.',
  ]);
}

/// Thrown when navigation fails due to an unmounted BuildContext or unavailable Navigator.
class IcueNavigationException extends IcueException {
  const IcueNavigationException([
    super.message =
        'Navigator state or BuildContext is not mounted. Ensure MaterialApp has navigatorKey: IcueSdk.navigatorKey.',
  ]);
}

/// Represents the typed outcome of attempting to open live tracking.
@immutable
sealed class IcueLaunchResult {
  const IcueLaunchResult();

  const factory IcueLaunchResult.success() = IcueLaunchSuccess;

  const factory IcueLaunchResult.buffered({required String identificationNo}) =
      IcueLaunchBuffered;

  const factory IcueLaunchResult.failure({required IcueException error}) =
      IcueLaunchFailure;

  /// Whether navigation to live tracking completed immediately.
  bool get isSuccess => this is IcueLaunchSuccess;

  /// Whether navigation was buffered to execute once the root navigator is mounted.
  bool get isBuffered => this is IcueLaunchBuffered;

  /// Whether opening live tracking failed.
  bool get isFailure => this is IcueLaunchFailure;

  /// Error message if this result is a failure, otherwise `null`.
  String? get errorMessage => switch (this) {
        IcueLaunchFailure(error: final err) => err.message,
        _ => null,
      };
}

/// Tracking flow successfully opened on the navigator stack.
@immutable
class IcueLaunchSuccess extends IcueLaunchResult {
  const IcueLaunchSuccess();

  @override
  String toString() => 'IcueLaunchResult.success()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IcueLaunchSuccess;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Root navigator was not yet mounted; navigation is buffered and will replay
/// automatically once the navigator becomes active.
@immutable
class IcueLaunchBuffered extends IcueLaunchResult {
  const IcueLaunchBuffered({required this.identificationNo});

  final String identificationNo;

  @override
  String toString() =>
      'IcueLaunchResult.buffered(identificationNo: $identificationNo)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcueLaunchBuffered &&
          runtimeType == other.runtimeType &&
          identificationNo == other.identificationNo;

  @override
  int get hashCode => Object.hash(runtimeType, identificationNo);
}

/// Navigation to tracking failed with a typed [error].
@immutable
class IcueLaunchFailure extends IcueLaunchResult {
  const IcueLaunchFailure({required this.error});

  final IcueException error;

  @override
  String toString() => 'IcueLaunchResult.failure(error: $error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcueLaunchFailure &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => Object.hash(runtimeType, error);
}
