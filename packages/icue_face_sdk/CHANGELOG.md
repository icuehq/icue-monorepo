## 0.2.0

- Added an SDK-owned CameraX capture flow that returns a face embedding.
- Added an SDK-owned live face-tracking flow with frame dimensions and timestamps.
- Added optional profile matching to live tracking responses.
- Added a complete local enrollment and live-recognition example flow.
- Exposed the same camera functionality to Flutter Android and native Android apps.
- Added front/back camera selection, runtime camera permission handling, preview
  overlays, cancellation, errors, and latest-frame backpressure.

## 0.1.0

- Replaced the legacy Interpreter with LiteRT 2.1.6 CompiledModel execution.
- Added explicit CPU, GPU, and NPU accelerator selection without runtime fallback.
- Added a standalone native Android face-recognition AAR.
- Added Flutter Android APIs for static images, NV21, and planar YUV420 frames.
- Added MobileFaceNet tensor validation and reusable inference buffers.
- Removed JPEG conversion from the camera-frame pipeline.
- Added typed errors, lifecycle management, live-frame backpressure, tests,
  integration fixtures, and a device latency harness.
