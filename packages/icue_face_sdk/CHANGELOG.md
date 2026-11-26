## Unreleased

- Fixed face alignment turning every face upside down (eyes were paired with the
  wrong template points). Embeddings made before this fix do not match new ones:
  regenerate every enrolled face.
- A face is matched only when it beats the next-closest student by 0.05; near ties
  stay unmatched instead of getting a guessed name.
- Live attendance marks a student present only after two separate model runs agree.
- Live tracking re-checks a tracked face as soon as it stops looking like the face
  that was recognized, so a face swapped into the same spot no longer keeps the
  previous student's name.
- Enrollment rejects faces without visible eyes or turned away (`POOR_FACE`) instead
  of using an unaligned crop. Recognition skips them and faces under 30 px.
- Android front-camera frames are no longer mirrored before recognition; face boxes
  are in unmirrored image coordinates. Results carry `reused` for replayed tracking.
- Attendance camera (Android and iOS): no close (✕) button, and Android back no
  longer cancels. A Cancel button sits next to Finish, which shows the scanned count.
  Cancel with nothing scanned closes at once; otherwise a custom popup shows the
  count large and three full-width buttons: Submit, Discard all scans, Keep scanning. Results reach the host as before: Submit as a
  completed attendance, Discard as a cancel. On iOS the old ✕ submitted attendance;
  it now matches Android.
- Live attendance (Android) shows the green tick and name only once a student is
  counted, and re-checks an unconfirmed face on the next frame, so the tick, the
  count and the beep always happen together.
- Live attendance (Android) reports a face as unregistered only after three model
  runs found no student and it was never counted; `unrecognizedFaceCount` is the
  number of such people at the end. Unknown people are told apart by their face
  embeddings, not tracking IDs, so they are counted once each. Before, a student's first unmatched frames could
  leave "1 unregistered" in the summary even after they were recognized.
- Attendance plays one beep and one firm vibration each time new students are
  marked present. Both platforms play the beep even on
  silent: Android on the alarm stream (adds the install-time `VIBRATE`
  permission), iOS through a `.playback` audio session that mixes with other audio
  and restores the host's category when the camera closes.
- iOS images are redrawn upright before detection, so camera frames align correctly.

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
