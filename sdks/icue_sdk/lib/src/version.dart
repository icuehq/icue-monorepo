/// The SDK version. Must equal `version:` in pubspec.yaml. `tool/release.dart`
/// updates both; a unit test enforces it.
const String icueSdkVersion = '0.2.0-beta.3';

/// True for prerelease builds (`X.Y.Z-beta.N`), which are not production ready.
bool get icueSdkIsBeta => icueSdkVersion.contains('-');
