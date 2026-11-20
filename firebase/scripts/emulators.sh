#!/usr/bin/env bash
# Local emulator suite (auth, firestore, functions, storage) with persisted data.
#   emulators.sh start [standard|enterprise]   build Functions, load the edition's saved data if present,
#                                              save to it on exit (Ctrl-C); default standard
#   emulators.sh reset                         delete the saved data of both editions
# The Firestore emulator runs one edition per process (emulators.firestore.edition), so each edition
# keeps its own data directory: exports are not interchangeable.
# Runs as icueadmin-dev: Android/iOS apps take their project ID from google-services.json, so the
# emulators must answer on that project. All four services are emulated; outboxSend skips real
# FCM sends when running in the emulator, so nothing reaches the real project.
set -euo pipefail
cd "$(dirname "$0")/.."

EDITION=${2:-standard}
DATA=.emulator-data
[ "$EDITION" = enterprise ] && DATA=.emulator-data-enterprise
# EMULATOR_DATA=<dir> keeps a separate data set (the e2e suite uses .emulator-data-e2e) so it never
# touches development data. The app hard-codes the emulator ports: run one emulator set at a time.
DATA=${EMULATOR_DATA:-$DATA}
PROJECT=icueadmin-dev

case "${1:-}" in
  start)
    # Ctrl-C through melos can orphan emulator children (Firestore java, Functions node) that keep
    # the ports bound. Free this project's configured ports before starting.
    ports=$(grep -o '"port": *[0-9]*' firebase.json | grep -o '[0-9]*$' | sort -u)
    for port in $ports; do
      pids=$(lsof -ti "tcp:$port" -sTCP:LISTEN 2>/dev/null || true)
      [ -n "$pids" ] && { echo "Port $port in use by leftover process(es) $pids; stopping"; kill $pids || true; }
    done
    npm --prefix functions install --no-audit --no-fund --silent
    npm --prefix functions run build
    case "$EDITION" in standard|enterprise) ;; *) echo "Edition must be standard or enterprise" >&2; exit 1 ;; esac
    config=.firebase.emulator.json
    node -e '
      const fs = require("fs");
      const config = JSON.parse(fs.readFileSync("firebase.json", "utf8"));
      config.emulators.firestore = { ...config.emulators.firestore, edition: process.argv[1] };
      fs.writeFileSync(process.argv[2], JSON.stringify(config, null, 2));
    ' "$EDITION" "$config"
    echo "Firestore emulator edition: $EDITION (data: firebase/$DATA)"
    args=(--config "$config" --project "$PROJECT" --export-on-exit "$DATA")
    [ -d "$DATA" ] && args+=(--import "$DATA")
    # Ctrl-C closing our stdout (melos, closed terminal) makes the CLI hit EPIPE mid export-on-exit and
    # dump to ./firebase-export-<timestamp> instead of $DATA. Send its output to a file (no pipe to
    # break), mirror it with tail, and stay alive until the CLI has finished exporting.
    log=$(mktemp -t firebase-emulators)
    firebase emulators:start "${args[@]}" >"$log" 2>&1 &
    cli=$!
    tail -f "$log" &
    tailer=$!
    trap '' INT
    status=0
    while kill -0 "$cli" 2>/dev/null; do wait "$cli" || status=$?; done
    kill "$tailer" 2>/dev/null || true
    rm -f "$log"
    exit "$status"
    ;;
  reset)
    if [ -n "${EMULATOR_DATA:-}" ]; then
      rm -rf "$EMULATOR_DATA"
      echo "Removed firebase/$EMULATOR_DATA"
    else
      rm -rf .emulator-data .emulator-data-enterprise
      echo "Removed firebase/.emulator-data and firebase/.emulator-data-enterprise"
    fi
    ;;
  *)
    echo "Usage: $0 start|reset" >&2
    exit 1
    ;;
esac
