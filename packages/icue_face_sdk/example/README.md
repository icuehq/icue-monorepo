# iCue Face SDK example

The example initializes the bundled Android inference runtime and reports its
model metadata. The integration suite exercises real face fixtures, planar YUV
conversion, recognition ordering, and warm inference latency.

```bash
flutter run
flutter test
flutter test integration_test/plugin_integration_test.dart
```

Native integration tests require an Android API 24+ device or emulator.
