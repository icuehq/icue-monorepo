#!/usr/bin/env bash
# Runs the whole Maestro suite (order and flow list in e2e/maestro/config.yaml) in ONE Maestro process against the
# Android emulator. Needs `melos run e2e:emulators` running and the dev app installed.
# Env: DEVICE (default emulator-5554), JAVA_HOME (JDK 21), SKIP_ANIMATIONS=0 to keep emulator animations.
set -uo pipefail
cd "$(dirname "$0")/../maestro"
export PATH="$PATH:$HOME/.maestro/bin" MAESTRO_CLI_NO_ANALYTICS=1 MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
DEVICE=${DEVICE:-emulator-5554}
if [ "${SKIP_ANIMATIONS:-1}" = 1 ]; then # animations make every tap wait for the UI to settle
  for key in window_animation_scale transition_animation_scale animator_duration_scale; do
    adb -s "$DEVICE" shell settings put global "$key" 0
  done
fi
exec maestro --device "$DEVICE" test .
