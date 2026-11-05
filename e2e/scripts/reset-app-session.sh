#!/usr/bin/env bash
# Drops the app's cached Firebase user (not the Node login) so the next launch re-exchanges the token
# and session-sync recreates userAccess. Run after resetting the e2e emulator data.
set -euo pipefail
APP=com.thoughtniques.icueadmin.dev
adb shell am force-stop "$APP"
adb shell "run-as $APP sh -c 'rm -f shared_prefs/com.google.firebase.auth*'"
